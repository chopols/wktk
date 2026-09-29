/// 접속자(Peer) 모델 (Flutter 비의존 순수 Dart).
library;

class Peer {
  const Peer({
    required this.id,
    required this.nickname,
    required this.address,
    required this.port,
    required this.lastSeen,
    required this.txActive,
  });

  /// senderId (UUID 문자열).
  final String id;
  final String nickname;

  /// 유니캐스트 폴백 수신처.
  final String address;
  final int port;
  final DateTime lastSeen;
  final bool txActive;

  Peer copyWith({
    String? nickname,
    String? address,
    int? port,
    DateTime? lastSeen,
    bool? txActive,
  }) {
    return Peer(
      id: id,
      nickname: nickname ?? this.nickname,
      address: address ?? this.address,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      txActive: txActive ?? this.txActive,
    );
  }
}
