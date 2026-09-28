/// 무전기 프로토콜 패킷 모델 (Flutter 비의존 순수 Dart).
///
/// `radio_sim`이 `dart run`으로 실행되므로 이 파일은 flutter 패키지를 참조하지 않는다.
library;

import 'dart:typed_data';

/// 패킷 타입. BaseHeader.type 값과 1:1.
enum PacketType {
  presence(0),
  txStart(1),
  txEnd(2),
  audio(3);

  const PacketType(this.value);

  final int value;

  static PacketType? fromValue(int v) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

enum AudioCodec {
  pcmS16Le16kMono(0),
  opusReserved(1);

  const AudioCodec(this.value);

  final int value;
}

/// 40바이트 BaseHeader (little-endian).
class RadioHeader {
  const RadioHeader({
    required this.type,
    required this.headerLen,
    required this.payloadLen,
    required this.seq,
    required this.channel,
    required this.codec,
    required this.sampleRate,
    required this.timestampMs,
    required this.senderId,
  });

  static const int kSize = 40;

  final PacketType type;
  final int headerLen;
  final int payloadLen;
  final int seq;
  final int channel;
  final int codec;
  final int sampleRate;
  final int timestampMs;

  /// 16바이트 raw UUID (senderId).
  final Uint8List senderId;
}

/// UUID 문자열 <-> 16바이트 변환.
Uint8List uuidToBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  if (hex.length != 32) {
    throw ArgumentError('잘못된 UUID: $uuid');
  }
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

String uuidFromBytes(Uint8List bytes) {
  assert(bytes.length == 16);
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// PRECENSE body: nickLen(1) + nick(≤32) + txActive(1).
class PresenceBody {
  const PresenceBody({required this.nickname, required this.txActive});

  final String nickname;
  final bool txActive;
}

/// TX_START body: nickLen(1) + nick + talkMs(2, LE).
class TxStartBody {
  const TxStartBody({required this.nickname, required this.talkMs});

  final String nickname;
  final int talkMs;
}

/// TX_END body: nickLen(1) + nick.
class TxEndBody {
  const TxEndBody({required this.nickname});

  final String nickname;
}

/// 디코딩 결과.
class DecodedPacket {
  const DecodedPacket({required this.header, required this.body});

  final RadioHeader header;
  final Uint8List body;
}
