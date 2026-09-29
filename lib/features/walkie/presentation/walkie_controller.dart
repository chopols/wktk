/// 무전기 화면 컨트롤러.
///
/// Step 1~2: UI 골격 + 네트워크(Wi-Fi) 상태 연동.
/// Step 4: TransceiverService(PRESENCE/TX_START/TX_END/AUDIO) + 마이크 캡처 + 재생 연결.
/// Step 5: 지터버퍼(순서 복원/중복 폐기/PLC), 반이중 중재(거부/충돌), VOX,
///   수신 노이즈 게이트, 효과음(roger/squelch/denied)·햅틱.
/// Step 9: 전원 ON/OFF(포그라운드 서비스로 백그라운드 대기) + 상대 PTT 자동 전화.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/network_monitor.dart';
import '../../../core/network/transport/dart_udp_transport.dart';
import '../../../core/network/transport/native/multicast_lock_channel.dart';
import '../../../core/platform/notification_permission.dart';
import '../../../core/platform/power_channel.dart';
import '../../../core/utils/kv_store.dart';
import '../data/audio/audio_capture.dart';
import '../data/audio/audio_playback.dart';
import '../data/audio/pcm_slicer.dart';
import '../data/audio/sound_effects.dart';
import '../data/channel_arbiter.dart';
import '../data/jitter_buffer.dart';
import '../data/peer_registry.dart';
import '../data/transceiver_service.dart';
import '../domain/peer.dart';
import '../domain/walkie_state.dart';

class WalkieController extends Notifier<WalkieUiState> {
  TransceiverService? _service;
  AudioCapture? _capture;
  AudioPlayback? _playback;
  SoundEffects? _effects;
  PcmSlicer? _slicer;
  JitterBuffer? _jitter;
  StreamSubscription<List<Peer>>? _peersSub;
  StreamSubscription<ReceivedAudio>? _audioSub;
  StreamSubscription<BusEvent>? _busSub;
  Timer? _rxIdleTimer;
  Timer? _drainTimer;
  Timer? _busyDeniedTimer;
  Timer? _collisionTimer;
  AppLifecycleListener? _lifecycle;
  int _frameCounter = 0;
  DateTime? _lastAudioAt;
  DateTime? _lastIncomingCallAt;
  bool _starting = false;
  int _voxSpeechMs = 0;
  int _voxSilenceMs = 0;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  TransceiverService? get service => _service;

  @override
  WalkieUiState build() {
    // 네트워크(Wi-Fi) 연결/해제 시 세션 라이프사이클. fireImmediately 없이
    // 변경 시에만 호출되므로 이전 빌드 중 `state=` 쓰기 트랩에서 자유롭다.
    ref.listen(networkStatusProvider, (_, next) {
      if (!state.powerOn) return;
      if (next.connected) {
        unawaited(_ensureSession(localIPv4: next.localIPv4));
      } else {
        unawaited(_teardownSession());
      }
    });
    // 앱이 포그라운드인 동안 `resumed` 로 유지해, 백그라운드일 때만 상대 PTT 전화가
    // 자동으로 올라오도록 구분한다.
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) => _lifecycleState = s,
      onResume: () => unawaited(_onResume()),
    );
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
      unawaited(_teardownSession());
    });
    // 저장된 설정을 상태로 미리 반영 (세션 시작 전에도 설정 화면이 최신값 표시).
    unawaited(_loadPersistedSettings());
    // 앱 실행 = 전원 ON. 백그라운드에서 계속 대기할 수 있도록 서비스를 기동한다.
    // (Notifier.build() 안에서 바로 state= 를 쓰면 초기화 전 참조가 되므로 마이크로태스크로 미룬다)
    scheduleMicrotask(_powerOn);
    return WalkieUiState.initial;
  }

  // ── 전원 (프로세스 수명 통제) ─────────────────────────────

  /// 전원 ON: 백그라운드 대기용 포그라운드 서비스를 기동한다.
  Future<void> _powerOn() async {
    if (!ref.mounted) return;
    state = state.copyWith(powerOn: true);
    await PowerChannel.setPower(true);
    // 상시 알림(전원 표시)을 보이기 위한 알림 권한(Android 13+).
    unawaited(NotificationPermission.ensure());
  }

  /// 전원 OFF: 세션을 정리하고 **전체 프로세스를 완전히 종료**한다.
  ///
  /// 전원 ON 상태만 정상 동작하므로 OFF는 상태 머신으로 남기지 않고 네이티브에서
  /// 서비스 정지 + `Process.killProcess` 로 프로세스 자체를 끝낸다(앱 재실행 시 다시 ON).
  Future<void> powerOff() async {
    if (!state.powerOn) return;
    state = state.copyWith(powerOn: false);
    await _teardownSession();
    if (!ref.mounted) return;
    await PowerChannel.setPower(false);
    // 채널이 없는 환경(iOS/테스트)에서는 Activity 만 종료한다.
    await SystemNavigator.pop();
  }

  /// 포그라운드 복귀: 세션이 살아 있으면 유지하고, 죽었을 때만 다시 기동한다.
  /// (전원 ON 중에는 서비스가 프로세스를 붙잡고 있으므로 매번 재기동하면 안 된다.)
  Future<void> _onResume() async {
    if (!state.powerOn) return;
    final net = ref.read(networkStatusProvider);
    if (!net.connected) return;
    await PowerChannel.setPower(true); // 서비스가 정리됐을 수 있어 재확인
    if (_service?.started ?? false) return;
    await _ensureSession(localIPv4: net.localIPv4);
  }

  /// 백그라운드 대기 중 상대 PTT → 자동 전화(알림·진동 + 포그라운드 전환).
  void _maybeCallFromBackground(String? talker) {
    if (!state.powerOn) return;
    if (_lifecycleState == AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final last = _lastIncomingCallAt;
    if (last != null &&
        now.difference(last) < AppConstants.kIncomingCallCooldown) {
      return;
    }
    _lastIncomingCallAt = now;
    final name = talker?.trim();
    state = state.copyWith(
      incomingCaller: (name == null || name.isEmpty) ? null : name,
    );
    unawaited(PowerChannel.ring(talker: name, channel: state.channel));
  }

  /// '접속 확인' 버튼: 네트워크에 연결돼 있으면 세션을 재기동한다.
  /// [bool] 반환 = 재기동을 시도했는지(미연결/통화 중이면 false).
  Future<bool> checkConnection() async {
    if (!state.powerOn) return false;
    final net = ref.read(networkStatusProvider);
    if (!net.connected) return false;
    await restartSession(localIPv4: net.localIPv4);
    return true;
  }

  // ── 세션 ────────────────────────────────────────────────

  /// 영속화된 설정을 읽어 UI 상태에 반영한다.
  Future<void> _loadPersistedSettings() async {
    final nickname = await AppPrefs.nickname();
    final channel = await AppPrefs.defaultChannel();
    final volume = await AppPrefs.volume();
    final effects = await AppPrefs.effectsEnabled();
    final haptics = await AppPrefs.hapticsEnabled();
    final vox = await AppPrefs.voxEnabled();
    final gate = await AppPrefs.noiseGateEnabled();
    if (!ref.mounted) return;
    state = state.copyWith(
      localNickname: nickname.isEmpty ? '나' : nickname,
      channel: channel.clamp(1, AppConstants.kChannelCount).toInt(),
      volume: volume.clamp(0.0, 1.0).toDouble(),
      effectsEnabled: effects,
      hapticsEnabled: haptics,
      voxEnabled: vox,
      noiseGateEnabled: gate,
    );
  }

  Future<void> _ensureSession({String? localIPv4}) async {
    if (!state.powerOn) return;
    if (_starting) return;
    if (_service?.started ?? false) return;
    _starting = true;
    try {
      // 세션 시작 시점에도 저장 설정을 새로 읽어 이전 시점 경합을 피한다.
      final nickname = await AppPrefs.nickname();
      final nick = nickname.isEmpty ? '나' : nickname;
      final channel = (await AppPrefs.defaultChannel())
          .clamp(1, AppConstants.kChannelCount)
          .toInt();
      final volume = (await AppPrefs.volume()).clamp(0.0, 1.0).toDouble();
      final effects = await AppPrefs.effectsEnabled();
      final haptics = await AppPrefs.hapticsEnabled();
      final vox = await AppPrefs.voxEnabled();
      final gate = await AppPrefs.noiseGateEnabled();
      if (!ref.mounted) return;
      state = state.copyWith(
        localNickname: nick,
        channel: channel,
        volume: volume,
        effectsEnabled: effects,
        hapticsEnabled: haptics,
        voxEnabled: vox,
        noiseGateEnabled: gate,
        sessionError: null,
      );

      final transport = DartUdpTransport(
        multicastLockAcquire: MulticastLockChannel.acquire,
        multicastLockRelease: MulticastLockChannel.release,
      );
      final service = TransceiverService(
        transport: transport,
        registry: PeerRegistry(),
      );
      await service.start(
        nickname: nick,
        channel: state.channel,
        localIPv4: localIPv4,
      );

      _service = service;
      _capture = AudioCapture();
      _playback = AudioPlayback();
      _effects = SoundEffects(enabled: state.effectsEnabled);
      _jitter = JitterBuffer(
        targetMs: AppConstants.kJitterBuffer.inMilliseconds,
        maxDropMs: AppConstants.kJitterBufferFlushDropGap,
        maxReplayGapFrames: 6,
      );
      await _playback!.init(volume: state.volume);
      await _effects!.init();

      _peersSub = service.onPeersChanged.listen(_onPeersChanged);
      _audioSub = service.onAudio.listen(_onAudio);
      _busSub = service.onBusEvent.listen(_onBusEvent);
      _drainTimer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => _drainJitter(),
      );

      state = state.copyWith(
        peerCount: service.peerCount,
        peers: service.peers,
      );
      if (state.voxEnabled) {
        await _startVoxCapture();
      }
    } catch (e, st) {
      debugPrint('세션 시작 실패: $e\n$st');
      if (ref.mounted) {
        state = state.copyWith(sessionError: '$e');
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _teardownSession() async {
    _slicer = null;
    _drainTimer?.cancel();
    _drainTimer = null;
    _busyDeniedTimer?.cancel();
    _busyDeniedTimer = null;
    _collisionTimer?.cancel();
    _collisionTimer = null;
    await _capture?.dispose();
    _capture = null;
    await _playback?.dispose();
    _playback = null;
    _peersSub?.cancel();
    _peersSub = null;
    _audioSub?.cancel();
    _audioSub = null;
    _busSub?.cancel();
    _busSub = null;
    _rxIdleTimer?.cancel();
    _rxIdleTimer = null;
    _jitter?.reset();
    _jitter = null;
    await _service?.stop();
    _service = null;
    if (!ref.mounted) return;
    state = state.copyWith(
      peerCount: 0,
      peers: const <Peer>[],
      txStatus: TxStatus.idle,
      signalLevel: 0.0,
      channelBusy: false,
      talkerNickname: null,
      incomingCaller: null,
    );
  }

  void _onPeersChanged(List<Peer> peers) {
    final talking = peers.any((p) => p.txActive);
    state = state.copyWith(
      peerCount: peers.length,
      peers: List<Peer>.unmodifiable(peers),
      channelBusy: talking,
    );
  }

  void _onBusEvent(BusEvent e) {
    switch (e.kind) {
      case BusEventKind.collision:
        // 서비스가 이미 우리 송신을 중단했다. UI/효과만 정리.
        _slicer?.clear();
        _voxSpeechMs = 0;
        _voxSilenceMs = 0;
        _collisionTimer?.cancel();
        if (state.hapticsEnabled) HapticFeedback.heavyImpact();
        if (state.effectsEnabled) _effects?.denied();
        state = state.copyWith(txStatus: TxStatus.collision);
        final nickname = e.nickname;
        if (nickname != null && nickname.isNotEmpty) {
          state = state.copyWith(talkerNickname: '$nickname 님과 충돌');
        }
        _collisionTimer = Timer(const Duration(seconds: 1), () {
          _collisionTimer = null;
          if (ref.mounted && state.txStatus == TxStatus.collision) {
            state = state.copyWith(
              txStatus: TxStatus.idle,
              talkerNickname: null,
            );
          }
        });
      case BusEventKind.remoteStarted:
        if (state.effectsEnabled) _effects?.squelch();
        // 백그라운드 대기 중이면 상대 PTT에 자동으로 전화를 건다.
        _maybeCallFromBackground(e.nickname);
    }
  }

  void _onAudio(ReceivedAudio rx) {
    final playback = _playback;
    // 노이즈 게이트(squelch): 저전력 프레임은 침묵 처리.
    if (state.noiseGateEnabled) {
      final rms = pcm16Rms(rx.pcm);
      if (rms < AppConstants.kNoiseGateThreshold) return;
      state = state.copyWith(signalLevel: rms);
    }
    final now = DateTime.now();
    final newBurst =
        _lastAudioAt == null ||
        now.difference(_lastAudioAt!) > AppConstants.kRxIdleTimeout;
    if (newBurst) {
      _jitter?.resetStats();
      _jitter?.reset();
      playback?.reset();
      // PRESENCE(txActive)로 이미 버스가 점유된 뒤 첫 오디오가 도착하는 경우에도
      // 버스트 첫 프레임에서 백그라운드 전화가 누락되지 않도록 여기서도 감지한다.
      _maybeCallFromBackground(rx.nickname);
    }
    _lastAudioAt = now;
    _jitter?.offer(rx.seq, rx.pcm);

    _rxIdleTimer?.cancel();
    _rxIdleTimer = Timer(AppConstants.kRxIdleTimeout, () {
      _rxIdleTimer = null;
      if (state.txStatus == TxStatus.receiving) {
        state = state.copyWith(
          txStatus: TxStatus.idle,
          talkerNickname: null,
          incomingCaller: null,
        );
      }
    });
    state = state.copyWith(
      txStatus: TxStatus.receiving,
      talkerNickname: rx.nickname.isEmpty ? '알 수 없음' : rx.nickname,
    );
  }

  void _drainJitter() {
    final j = _jitter;
    final playback = _playback;
    if (j == null) return;
    final ready = j.drain();
    for (final frame in ready) {
      playback?.feed(frame);
    }
  }

  // ── 송신 (PTT / VOX 공용) ───────────────────────────────

  Future<void> pttDown() async {
    if (!state.powerOn) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (!ref.read(networkStatusProvider).connected) {
      HapticFeedback.heavyImpact();
      return;
    }
    await _ensureSession(localIPv4: ref.read(networkStatusProvider).localIPv4);
    await _beginTransmit();
  }

  Future<void> pttUp() => _endTransmit(stopCapture: true);

  /// 송신 시작(PTT down / VOX 발화). false = 채널 사용 중 거부.
  Future<bool> _beginTransmit() async {
    final service = _service;
    if (service == null || !service.started) return false;
    if (service.isTransmitting) return true;

    // 반향 방지: 마이크로 내 목소리가 다시 들리는 것을 막기 위해 송신 전 재생 버퍼를 비운다.
    _playback?.reset();
    final granted = await service.startTransmit();
    if (!granted) {
      _onBusyDenied();
      return false;
    }
    _slicer ??= PcmSlicer(frameSize: AppConstants.kFrameBytes);
    _frameCounter = 0;
    final capture = _capture;
    if (capture != null && !capture.isRecording) {
      try {
        await capture.start(onPcm: _onMicChunk);
      } catch (e, st) {
        debugPrint('캡처 시작 실패: $e\n$st');
        _slicer?.clear();
        await service.stopTransmit();
        return false;
      }
    }
    _markTransmitStart();
    return true;
  }

  Future<void> _endTransmit({required bool stopCapture}) async {
    final service = _service;
    final wasTx = service?.isTransmitting ?? false;
    if (stopCapture) {
      await _capture?.stop();
      _slicer?.clear();
    }
    await service?.stopTransmit();
    if (wasTx && state.txStatus == TxStatus.transmitting) {
      _markTransmitEnd();
    }
  }

  void _markTransmitStart() {
    state = state.copyWith(txStatus: TxStatus.transmitting);
    if (state.voxEnabled) return; // VOX는 효과음/햅틱 없이 조용히
    if (state.hapticsEnabled) HapticFeedback.mediumImpact();
    if (state.effectsEnabled) _effects?.rogerBeep();
  }

  void _markTransmitEnd() {
    state = state.copyWith(txStatus: TxStatus.idle, signalLevel: 0.0);
    if (state.voxEnabled) return;
    if (state.hapticsEnabled) HapticFeedback.lightImpact();
    if (state.effectsEnabled) _effects?.rogerBeep();
  }

  /// 채널 사용 중 거부: busy 배너 + 비프 + 햅틱.
  void _onBusyDenied() {
    if (_busyDeniedTimer != null) return;
    if (state.hapticsEnabled) HapticFeedback.heavyImpact();
    if (state.effectsEnabled) _effects?.denied();
    state = state.copyWith(txStatus: TxStatus.busy);
    _busyDeniedTimer = Timer(const Duration(milliseconds: 600), () {
      _busyDeniedTimer = null;
      if (ref.mounted && state.txStatus == TxStatus.busy) {
        state = state.copyWith(txStatus: TxStatus.idle);
      }
    });
  }

  void _onMicChunk(Uint8List chunk) {
    final service = _service;
    final slicer = _slicer;
    if (service == null || slicer == null) return;
    final rms = pcm16Rms(chunk);
    if (state.voxEnabled) _voxTick(rms);
    final frames = slicer.push(chunk);
    if (frames.isEmpty) return;
    for (final frame in frames) {
      if (!service.isTransmitting) return; // VOX 미발화 구간은 폐기
      service.sendAudioFrame(frame);
      // 신호 레벨 미터 갱신은 ~50 Hz가 부담되므로 5프레임(100 ms)마다 한 번.
      _frameCounter++;
      if (_frameCounter % 5 == 1) {
        state = state.copyWith(
          txStatus: TxStatus.transmitting,
          signalLevel: rms,
        );
      }
    }
  }

  void _voxTick(double rms) {
    if (rms >= AppConstants.kVoxEngageThreshold) {
      _voxSpeechMs += AppConstants.kFrameMs;
      _voxSilenceMs = 0;
      if (_voxSpeechMs >= AppConstants.kVoxEngageMs &&
          !(_service?.isTransmitting ?? true)) {
        _voxSpeechMs = 0;
        unawaited(_beginTransmit());
      }
    } else {
      _voxSpeechMs = 0;
      _voxSilenceMs += AppConstants.kFrameMs;
      if (_voxSilenceMs >= AppConstants.kVoxReleaseMs) {
        _voxSilenceMs = 0;
        if (_service?.isTransmitting ?? false) {
          unawaited(_endTransmit(stopCapture: false));
        }
      }
    }
  }

  /// VOX 연속 캡처 시작(PTT와 같은 onPcm 공유).
  Future<void> _startVoxCapture() async {
    final capture = _capture;
    if (capture == null) return;
    if (capture.isRecording) return;
    _slicer ??= PcmSlicer(frameSize: AppConstants.kFrameBytes);
    try {
      await capture.start(onPcm: _onMicChunk);
    } catch (e, st) {
      debugPrint('VOX 캡처 시작 실패: $e\n$st');
      _slicer = null;
    }
  }

  // ── 설정 ────────────────────────────────────────────────

  /// 닉네임 변경: 영속화 → 상태 갱신 → 세션 재시작(PRESENCE에 즉시 반영).
  void setNickname(String nickname) {
    var trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      trimmed = '나';
    } else if (trimmed.length > AppConstants.kMaxNicknameChars) {
      trimmed = trimmed.substring(0, AppConstants.kMaxNicknameChars);
    }
    unawaited(AppPrefs.setNickname(trimmed));
    state = state.copyWith(localNickname: trimmed);
    if (_service?.started ?? false) {
      unawaited(
        restartSession(localIPv4: ref.read(networkStatusProvider).localIPv4),
      );
    }
  }

  void setChannel(int channel) {
    final ch = channel.clamp(1, AppConstants.kChannelCount).toInt();
    if (ch == state.channel) return;
    state = state.copyWith(channel: ch); // 노치 햅틱은 노브의 knobTick이 담당
    unawaited(AppPrefs.setDefaultChannel(ch));
    if (_service?.started ?? false) {
      unawaited(_service!.changeChannel(ch));
    }
  }

  void setVolume(double volume) {
    final vol = volume.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(volume: vol);
    unawaited(AppPrefs.setVolume(vol));
    _playback?.setVolume(vol);
  }

  /// 노브 노치 1칸 당 틱 (선택 햅틱).
  void knobTick() {
    if (state.hapticsEnabled) HapticFeedback.selectionClick();
  }

  void setVoxEnabled(bool vox) {
    state = state.copyWith(voxEnabled: vox);
    unawaited(AppPrefs.setVoxEnabled(vox));
    _voxSpeechMs = 0;
    _voxSilenceMs = 0;
    if (vox) {
      unawaited(_startVoxCapture());
    } else {
      // 진행 중인 VOX 발화 종료, 더 이상 마이크가 필요 없으면 캡처 중지.
      if (_service?.isTransmitting ?? false) {
        unawaited(_endTransmit(stopCapture: false));
      } else {
        unawaited(_capture?.stop());
      }
    }
  }

  void setNoiseGateEnabled(bool gate) {
    state = state.copyWith(noiseGateEnabled: gate);
    unawaited(AppPrefs.setNoiseGateEnabled(gate));
  }

  void setEffectsEnabled(bool effects) {
    state = state.copyWith(effectsEnabled: effects);
    unawaited(AppPrefs.setEffectsEnabled(effects));
    _effects?.enabled = effects;
  }

  void setHapticsEnabled(bool haptics) {
    state = state.copyWith(hapticsEnabled: haptics);
    unawaited(AppPrefs.setHapticsEnabled(haptics));
  }

  /// 세션 재시작(닉네임 변경 등). teardown 후 재기동.
  Future<void> restartSession({String? localIPv4}) async {
    await _teardownSession();
    if (!ref.mounted) return;
    await _ensureSession(localIPv4: localIPv4);
  }

  /// 세션 실패 배너의 '다시 시도'.
  void retrySession() {
    final net = ref.read(networkStatusProvider);
    if (net.connected) {
      unawaited(restartSession(localIPv4: net.localIPv4));
    }
  }
}

final walkieControllerProvider =
    NotifierProvider<WalkieController, WalkieUiState>(WalkieController.new);

/// 네트워크 감지 결과를 화면 상태에 합성한 뷰 모델.
/// (채널/볼륨 등 사용자 조작은 유지되고 wifiOk/netKind만 실시간 반영)
final walkieUiProvider = Provider<WalkieUiState>((ref) {
  final core = ref.watch(walkieControllerProvider);
  final net = ref.watch(networkStatusProvider);
  return core.copyWith(wifiOk: net.connected, netKind: net.kind);
});
