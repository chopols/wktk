/// 접속자 레지스트리 (Flutter 비의존 순수 Dart).
///
/// PRESENCE 수신마다 갱신, 지정 시간(기본 8 s) 넘어 수신이 없으면 만료. 시계는 주입한다.
library;

import '../../../core/constants/app_constants.dart';
import '../domain/peer.dart';

class PeerRegistry {
  final Map<String, Peer> _peers = <String, Peer>{};

  List<Peer> get peers => List.unmodifiable(_peers.values);
  int get count => _peers.length;
  bool get isEmpty => _peers.isEmpty;

  Peer? byId(String id) => _peers[id];

  /// PRESENCE body로 접속자 추가/갱신.
  void upsertPresence({
    required String id,
    required String nickname,
    required String address,
    required int port,
    required bool txActive,
    required DateTime now,
  }) {
    final current = _peers[id];
    if (current == null) {
      _peers[id] = Peer(
        id: id,
        nickname: nickname,
        address: address,
        port: port,
        lastSeen: now,
        txActive: txActive,
      );
      return;
    }
    _peers[id] = current.copyWith(
      nickname: nickname,
      address: address,
      port: port,
      txActive: txActive,
      lastSeen: now,
    );
  }

  /// [timeout] 동안 PRESENCE가 없던 접속자 제거.
  void purge(DateTime now, {Duration timeout = AppConstants.kPeerTimeout}) {
    _peers.removeWhere((_, p) => now.difference(p.lastSeen) > timeout);
  }

  void remove(String id) => _peers.remove(id);

  void clear() => _peers.clear();
}
