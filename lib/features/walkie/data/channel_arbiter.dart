/// 반이중 버스 중재기 (순수 Dart).
///
/// ```
/// idle ──requestLocal──▶ txLocal ──releaseLocal──▶ idle
///   ▲                      │
///   │ peerStart-무시?      │ peerStart(Δt ≤ collisionWindow) → 충돌
///   └──────────────────────┘      (양측 중단)
/// rxRemote ◀── peerStart        busyOwner = (peerId, since)
///   │  ▲
///   │  └── peerEnd → guardMs 유지 → idle
///   └── tick: idleTimeout 초과 → idle
/// ```
/// txLocal도 [txIdleMs] 동안 keepalive 없으면 자동 해제(송신 중 멈춤 보호).
library;

/// 버스 상태.
enum ArbiterState { idle, txLocal, rxRemote }

class ChannelArbiter {
  ChannelArbiter({
    required this.now,
    this.collisionWindowMs = 250,
    this.guardMs = 250,
    this.idleTimeoutMs = 1200,
    this.txIdleMs = 400,
  });

  final int Function() now;
  final int collisionWindowMs;
  final int guardMs;
  final int idleTimeoutMs;
  final int txIdleMs;

  ArbiterState _state = ArbiterState.idle;
  String? _busyOwnerId;
  int _busySinceMs = 0;
  int _txStartMs = 0;
  int _lastLocalAudioMs = 0;
  int? _guardEndMs;
  bool _collision = false;

  ArbiterState get state => _state;

  /// 타인이 버스를 점유 중인지.
  bool get busyRemote => _state == ArbiterState.rxRemote;

  /// 현재 버스 소유자(자신이면 null).
  String? get busyOwnerId => _busyOwnerId;

  /// 충돌 플래그(1회 소비).
  bool takeCollision() {
    final c = _collision;
    _collision = false;
    return c;
  }

  /// PTT down. 반환 false = 채널 사용 중(busy)으로 거부.
  bool requestLocal() {
    final t = now();
    switch (_state) {
      case ArbiterState.idle:
        _state = ArbiterState.txLocal;
        _txStartMs = t;
        _lastLocalAudioMs = t;
        _guardEndMs = null;
        _busyOwnerId = null;
        return true;
      case ArbiterState.txLocal:
        return true;
      case ArbiterState.rxRemote:
        return false; // 상대 통화 중 → denied
    }
  }

  /// 로컬 오디오 프레임 발송마다 호출 (txLocal 자동 해제 방지/연장).
  void keepaliveLocal() {
    if (_state == ArbiterState.txLocal) {
      _lastLocalAudioMs = now();
    }
  }

  /// PTT up.
  void releaseLocal() {
    if (_state != ArbiterState.txLocal) return;
    _state = ArbiterState.idle;
    _busyOwnerId = null;
    _guardEndMs = null;
  }

  /// 타인 TX_START 도착.
  ///
  /// 반환값: `true` = 버스를 양보해야 함(우리가 송신 중이었다면 중단).
  /// 충돌은 [takeCollision]으로 별도 확인(우리 txLocal의 충돌 윈도 내).
  bool peerStart(String peerId) {
    final t = now();
    if (_state == ArbiterState.txLocal) {
      if (t - _txStartMs <= collisionWindowMs) {
        // 같은 순간 송신 시작 → 충돌
        _collision = true;
        return false;
      }
      // 충돌 윈도 통과 후 상대 시작 → 양보(rxRemote로 전이, 우리 송신 중단)
    }
    _beginRx(peerId);
    return true;
  }

  /// 타인 AUDIO 프레임 도착 (rxRemote 연장, 소유자 갱신).
  void peerAudio(String peerId) {
    if (_state != ArbiterState.rxRemote) return;
    _busyOwnerId = peerId;
    _busySinceMs = now();
    _guardEndMs = null;
  }

  /// 타인 TX_END 도착 → guard 후 idle 전이 예약.
  void peerEnd() {
    if (_state != ArbiterState.rxRemote) return;
    _guardEndMs = now() + guardMs;
  }

  /// 상대가 세션에서 이탈 → 즉시 해제.
  void peerLeft(String peerId) {
    if (_busyOwnerId != null && peerId != _busyOwnerId) return;
    if (_state == ArbiterState.rxRemote) {
      _state = ArbiterState.idle;
      _busyOwnerId = null;
      _guardEndMs = null;
    }
  }

  /// 주기 호출: guard 만료 / rx 유휴 / tx 로컬 자동 해제.
  void tick() {
    final t = now();
    switch (_state) {
      case ArbiterState.idle:
        break;
      case ArbiterState.txLocal:
        if (t - _lastLocalAudioMs > txIdleMs) {
          _state = ArbiterState.idle;
          _busyOwnerId = null;
        }
      case ArbiterState.rxRemote:
        final guard = _guardEndMs;
        if (guard != null) {
          if (t >= guard) {
            _state = ArbiterState.idle;
            _busyOwnerId = null;
            _guardEndMs = null;
          }
          break;
        }
        if (t - _busySinceMs > idleTimeoutMs) {
          _state = ArbiterState.idle;
          _busyOwnerId = null;
        }
    }
  }

  void _beginRx(String peerId) {
    _state = ArbiterState.rxRemote;
    _busyOwnerId = peerId;
    _busySinceMs = now();
    _guardEndMs = null;
  }
}

/// 버스 이벤트 (앱/시뮬레이터 공유).
enum BusEventKind { collision, remoteStarted }

class BusEvent {
  const BusEvent(this.kind, {this.nickname});

  final BusEventKind kind;
  final String? nickname;

  @override
  String toString() => 'BusEvent($kind, $nickname)';
}
