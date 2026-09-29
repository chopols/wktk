/// 송수신 서비스: 소켓·프레즌스 타이머·레지스트리의 소유자.
///
/// Step 3: PRESENCE 루프 + PeerRegistry 유지.
/// Step 4: TX_START/TX_END/AUDIO 패킷 + `onAudio` 스트림.
/// 순수 Dart 유지(`dart run radio_sim` 호환): 멀티캐스트 락은 앱 쪽에서만 전달.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/packet.dart';
import '../../../core/network/packet_codec.dart';
import '../../../core/network/transport/transport.dart';
import '../domain/peer.dart';
import 'channel_arbiter.dart';
import 'peer_registry.dart';

/// 수신 오디오 이벤트.
typedef ReceivedAudio = ({
  String senderId,
  String nickname,
  int seq,
  int timestampMs,
  DateTime receivedAt,
  Uint8List pcm,
});

class TransceiverService {
  TransceiverService({
    required this.transport,
    this.codec = const PacketCodec(),
    required this.registry,
  });

  final RadioTransport transport;
  final PacketCodec codec;
  final PeerRegistry registry;

  String? _localId;
  String _nickname = '나';
  int _channel = AppConstants.kDefaultChannel;
  int _seq = 0;
  String? _localIpv4;
  Timer? _presenceTimer;
  StreamSubscription<ReceivedDatagram>? _packetSub;
  StreamController<List<Peer>>? _peersCtrl;
  StreamController<ReceivedAudio>? _audioCtrl;
  StreamController<BusEvent>? _busCtrl;
  late final ChannelArbiter _arbiter;
  bool _started = false;
  bool _transmitting = false;

  bool get started => _started;
  int get channel => _channel;
  String get localId => _localId ??= _generateId();
  bool get isTransmitting => _transmitting;
  bool get busyRemote => _arbiter.busyRemote;
  List<Peer> get peers => registry.peers;
  int get peerCount => registry.count;

  /// 접속자 목록 변경 스트림 (프레즌스 갱신/만료 시 발행).
  Stream<List<Peer>> get onPeersChanged =>
      _peersCtrl?.stream ?? const Stream.empty();

  /// 수신 오디오 프레임 스트림 (앱 쪽 재생기에서 구독).
  Stream<ReceivedAudio> get onAudio =>
      _audioCtrl?.stream ?? const Stream.empty();

  /// 채널 중재 이벤트(충돌/원격 발화 시작) 스트림.
  Stream<BusEvent> get onBusEvent => _busCtrl?.stream ?? const Stream.empty();

  static String _generateId() => _uuidV4();

  static String _uuidV4() {
    // 순수 Dart UUID v4 (로컬 식별용, 무단 접근 위험 없음).
    final r = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = r.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10
    return uuidFromBytes(bytes);
  }

  Future<void> start({
    required String nickname,
    required int channel,
    String? localIPv4,
  }) async {
    if (_started) return;
    _nickname = nickname;
    _channel = channel;
    _localIpv4 = localIPv4;
    transport.setLocalIpv4(localIPv4);

    await transport.start(channel: channel);

    _peersCtrl = StreamController<List<Peer>>.broadcast();
    _audioCtrl = StreamController<ReceivedAudio>.broadcast();
    _busCtrl = StreamController<BusEvent>.broadcast();
    _arbiter = ChannelArbiter(
      now: () => DateTime.now().millisecondsSinceEpoch,
      collisionWindowMs: AppConstants.kCollisionWindow.inMilliseconds,
      guardMs: AppConstants.kTxGuard.inMilliseconds,
      idleTimeoutMs: AppConstants.kRxIdleTimeout.inMilliseconds,
      txIdleMs: AppConstants.kTxIdleTimeout.inMilliseconds,
    );
    _packetSub = transport.onPacket.listen(_onPacket);

    _sendPresence();
    _presenceTimer = Timer.periodic(AppConstants.kPresenceInterval, (_) {
      _arbiter.tick();
      // txLocal 오디오 유실 등으로 자동 해제됐으면 로컬 송신 상태 동기화.
      if (_transmitting && _arbiter.state != ArbiterState.txLocal) {
        _interruptTransmit();
      }
      _sendPresence();
      registry.purge(DateTime.now());
      _emit();
    });
    _started = true;
  }

  Future<void> changeChannel(int newChannel) async {
    if (newChannel == _channel && _started) return;
    await stop();
    await start(
      nickname: _nickname,
      channel: newChannel,
      localIPv4: _localIpv4,
    );
  }

  Future<void> stop() async {
    if (!_started) {
      await transport.stop();
      _started = false;
      return;
    }
    _transmitting = false;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    await _packetSub?.cancel();
    _packetSub = null;
    registry.clear();
    await _peersCtrl?.close();
    _peersCtrl = null;
    await _audioCtrl?.close();
    _audioCtrl = null;
    await _busCtrl?.close();
    _busCtrl = null;
    await transport.stop();
    _started = false;
  }

  // ── 송신 (PTT) ──────────────────────────────────────────

  /// 송신 시작 시도. 채널 사용 중이면 false(거부). 충돌이면 이벤트로 통지.
  Future<bool> startTransmit() async {
    if (!_started) return false;
    if (_transmitting) return true;
    final granted = _arbiter.requestLocal();
    if (!granted) return false;
    _transmitting = true;
    _sendTxStart();
    return true;
  }

  /// 오디오 프레임(640 B PCM16 LE)을 3경로로 발송.
  Future<void> sendAudioFrame(Uint8List pcm, {int? timestampMs}) async {
    if (!_started || !_transmitting) return;
    _arbiter.keepaliveLocal();
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final packet = codec.encodeAudio(
      pcm: pcm,
      channel: _channel,
      seq: ++_seq,
      senderId: localId,
      timestampMs: ts,
    );
    await sendToAllRoutes(packet);
  }

  /// 송신 종료: TX_END 전송 + presence txActive 해제.
  Future<void> stopTransmit() async {
    if (!_started) return;
    if (!_transmitting) return;
    _transmitting = false;
    _arbiter.releaseLocal();
    _sendTxEnd();
  }

  /// 충돌/양보 등으로 진행 중이던 송신을 즉시 중단(TX_END 발송).
  void _interruptTransmit() {
    if (!_transmitting) return;
    _transmitting = false;
    _arbiter.releaseLocal();
    _sendTxEnd();
  }

  void _sendTxStart() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final packet = codec.encodeTxStart(
      nickname: _nickname,
      talkMs: 0,
      channel: _channel,
      seq: ++_seq,
      senderId: localId,
      timestampMs: ts,
    );
    transport.sendAll(packet);
  }

  void _sendTxEnd() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final packet = codec.encodeTxEnd(
      nickname: _nickname,
      channel: _channel,
      seq: ++_seq,
      senderId: localId,
      timestampMs: ts,
    );
    transport.sendAll(packet);
  }

  void _sendPresence() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final packet = codec.encodePresence(
      nickname: _nickname,
      txActive: _transmitting,
      channel: _channel,
      seq: ++_seq,
      senderId: localId,
      timestampMs: ts,
    );
    transport.sendAll(packet);
  }

  /// AUDIO/TX_* 패킷을 3경로(멀티캐스트+브로드캐스트+학습된 유니캐스트)로 발송.
  Future<void> sendToAllRoutes(Uint8List datagram) async {
    await transport.sendAll(datagram);
    for (final peer in registry.peers) {
      await transport.sendTo(datagram, peer.address);
    }
  }

  // ── 수신 ────────────────────────────────────────────────

  void _onPacket(ReceivedDatagram rx) {
    final decoded = codec.decode(rx.data);
    if (decoded == null) return;
    final theirId = uuidFromBytes(decoded.header.senderId);
    if (theirId == localId) return; // 멀티캐스트 루프백(자기 패킷) 폐기

    switch (decoded.header.type) {
      case PacketType.presence:
        PresenceBody body;
        try {
          body = codec.decodePresence(decoded.body);
        } on FormatException {
          return;
        }
        registry.upsertPresence(
          id: theirId,
          nickname: body.nickname,
          address: rx.from.address,
          port: rx.port,
          txActive: body.txActive,
          now: DateTime.now(),
        );
        // 신규 발화자(presence txActive)가 감청 중이던 채널을 즉시 busy로 인지.
        if (body.txActive && !_transmitting && !_arbiter.busyRemote) {
          _arbiter.peerStart(theirId);
        }
        _emit();
      case PacketType.txStart:
        TxStartBody startBody;
        try {
          startBody = codec.decodeTxStart(decoded.body);
        } on FormatException {
          return;
        }
        registry.upsertPresence(
          id: theirId,
          nickname: startBody.nickname,
          address: rx.from.address,
          port: rx.port,
          txActive: true,
          now: DateTime.now(),
        );
        _handleRemoteStart(theirId, startBody.nickname);
        _emit();
      case PacketType.txEnd:
        TxEndBody endBody;
        try {
          endBody = codec.decodeTxEnd(decoded.body);
        } on FormatException {
          return;
        }
        final peer = registry.byId(theirId);
        if (peer == null) return;
        registry.upsertPresence(
          id: theirId,
          nickname: endBody.nickname,
          address: peer.address,
          port: peer.port,
          txActive: false,
          now: DateTime.now(),
        );
        _arbiter.peerEnd();
        _emit();
      case PacketType.audio:
        _arbiter.peerAudio(theirId);
        final peer = registry.byId(theirId);
        final nickname = peer?.nickname ?? '';
        _audioCtrl?.add((
          senderId: theirId,
          nickname: nickname,
          seq: decoded.header.seq,
          timestampMs: decoded.header.timestampMs,
          receivedAt: DateTime.now(),
          pcm: decoded.body,
        ));
    }
  }

  /// 타인 발화 시작 처리: 충돌/양보 판정 + 이벤트 발행.
  void _handleRemoteStart(String peerId, String nickname) {
    final wasRx = _arbiter.busyRemote;
    final yielded = _arbiter.peerStart(peerId);
    final collision = _arbiter.takeCollision();
    if (collision) {
      _interruptTransmit(); // 우리 즉시 중단
      _busCtrl?.add(BusEvent(BusEventKind.collision, nickname: nickname));
      return;
    }
    if (yielded && _transmitting) {
      _interruptTransmit(); // 오래 걸린 통화에 양보
    }
    if (!wasRx && _arbiter.busyRemote) {
      _busCtrl?.add(BusEvent(BusEventKind.remoteStarted, nickname: nickname));
    }
  }

  void _emit() {
    _peersCtrl?.add(registry.peers);
  }
}
