// CLI 시뮬레이터이므로 print 사용을 허용.
// ignore_for_file: avoid_print

/// PC 라디오 시뮬레이터.
///
/// Step 3: 실제 UDP 트랜스포트로 PRESENCE를 주고받으며 접속자 목록을 표시한다.
/// Step 4: `--tone` 모드로 440 Hz AUDIO 프레임을 송신하고, 수신 오디오 통계를 출력한다.
/// 사용: `dart run tool/radio_sim.dart --channel 1 --nick sim-pc --tone`
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:wktk/core/constants/app_constants.dart';
import 'package:wktk/core/network/subnet.dart';
import 'package:wktk/core/network/transport/dart_udp_transport.dart';
import 'package:wktk/features/walkie/data/peer_registry.dart';
import 'package:wktk/features/walkie/data/transceiver_service.dart';

const _usage = '''
WKTK radio_sim (PC 시뮬레이터)

사용법:
  dart run tool/radio_sim.dart --channel 1 [--tone]

옵션:
  --channel 1..16   채널 (기본 1)
  --nick <이름>      표시 이름 (기본 sim-pc)
  --tone            440 Hz 사인 AUDIO 프레임을 지속 송신 (수신측 음성 확인용)
  --once            접속자를 목록에 한 번만 반영하고 종료 (자동 테스트용)
''';

void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    exit(0);
  }
  var channel = 1;
  var nickname = 'sim-pc';
  var once = false;
  var tone = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--channel':
        channel = i + 1 < args.length ? int.parse(args[++i]) : channel;
      case '--nick':
        nickname = i + 1 < args.length ? args[++i] : nickname;
      case '--once':
        once = true;
      case '--tone':
        tone = true;
    }
  }

  final localIpv4 = await _findPrivateIpv4();
  print('WKTK radio_sim — 채널 $channel, nick: $nickname, localIP: $localIpv4');

  final transport = DartUdpTransport();
  final service = TransceiverService(
    transport: transport,
    registry: PeerRegistry(),
  );

  await service.start(
    nickname: nickname,
    channel: channel,
    localIPv4: localIpv4,
  );
  print('송수신 시작. [Ctrl+C]로 종료');

  var audioFrames = 0;
  var audioBytes = 0;
  service.onAudio.listen((rx) {
    audioFrames++;
    audioBytes += rx.pcm.length;
    // 지연 = 수신 시각 - 발신 타임스탬프 (클록 차가 있을 수 있음)
    final latencyMs = rx.receivedAt
        .difference(DateTime.fromMillisecondsSinceEpoch(rx.timestampMs))
        .inMilliseconds;
    print(
      '[AUDIO] ${rx.nickname}: +${rx.pcm.length}B '
      '(seq ${rx.seq}, 추정 지연 $latencyMs ms)',
    );
  });

  void render() {
    final peers = service.peers;
    if (peers.isEmpty) {
      print(
        '  접속자 없음 — 같은 Wi-Fi에서 앱을 실행해 보세요.'
        ' (audio $audioFrames 프레임/$audioBytes B 수신)',
      );
      return;
    }
    for (final p in peers) {
      final tx = p.txActive ? ' ◉송신' : '';
      print('  • ${p.nickname} @ ${p.address}:${p.port}$tx');
    }
  }

  if (tone) {
    final toneSender = _ToneSender(service)..start();
    // Ctrl+C로 종료하면 정리.
    ProcessSignal.sigint.watch().listen((_) async {
      await toneSender.stop();
      await service.stop();
      exit(0);
    });
  }

  if (once) {
    final completer = Completer<void>();
    service.onPeersChanged.listen((_) {
      render();
      service.stop();
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future.timeout(const Duration(seconds: 12));
    exit(0);
  }

  service.onPeersChanged.listen((_) => render());
  Timer.periodic(const Duration(seconds: 2), (_) => render());
}

/// 440 Hz 사인파를 20 ms 프레임(640 B)으로 지속 송신.
/// PTT 절차(TX_START → AUDIO… → TX_END)를 모사해 수신측에서 청취 가능.
class _ToneSender {
  _ToneSender(this.service);

  final TransceiverService service;
  final int _sampleRate = AppConstants.kSampleRate;
  Timer? _timer;
  int _sampleIndex = 0;
  int _runs = 0;

  void start() {
    service.startTransmit().then((granted) {
      if (!granted) {
        print('[TONE] 채널 사용 중 — 송신 거부. 곧 다시 시도합니다.');
        return;
      }
      _timer = Timer.periodic(
        const Duration(milliseconds: AppConstants.kFrameMs),
        _tick,
      );
    });
  }

  void _tick(Timer _) {
    if (!service.isTransmitting) return; // 중재 거부 직후 등에는 전송하지 않음
    final frame = Uint8List(AppConstants.kFrameBytes);
    final bd = ByteData.sublistView(frame);
    const amplitude = 32768 * 0.4;
    for (var i = 0; i < AppConstants.kFrameSamples; i++) {
      final v =
          (amplitude * math.sin(2 * math.pi * 440 * _sampleIndex / _sampleRate))
              .round()
              .clamp(-32768, 32767);
      bd.setInt16(i * 2, v, Endian.little);
      _sampleIndex++;
    }
    service.sendAudioFrame(frame);
    _runs++;
    if (_runs % 50 == 0) {
      print('[TONE] ${_runs * AppConstants.kFrameMs ~/ 1000}s 송신 중…');
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await service.stopTransmit();
  }
}

Future<String?> _findPrivateIpv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        if (NetworkClassifier.isPrivateIPv4(addr.address)) {
          return addr.address;
        }
      }
    }
  } catch (_) {}
  return null;
}
