/// 무전기 패킷 인코더/디코더 (Flutter 비의존 순수 Dart).
///
/// BaseHeader(40B, LE) + body 규격은 `documents/IMPLEMENT.md` §4 참고.
/// `RadioHeader.kSize` 이후 오프셋의 flags/crypt 확장 지점은 `AppConstants`에 명시.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../constants/app_constants.dart';
import 'packet.dart';

class PacketCodec {
  const PacketCodec();

  static const int _maxNicknameLen = 32;

  // ── 인코딩 ──────────────────────────────────────────────

  /// PRESENCE 패킷 생성.
  Uint8List encodePresence({
    required String nickname,
    required bool txActive,
    required int channel,
    required int seq,
    required String senderId,
    required int timestampMs,
  }) {
    final nick = utf8.encode(nickname);
    if (nick.length > _maxNicknameLen) {
      throw ArgumentError('닉네임이 $_maxNicknameLen바이트를 초과');
    }
    final body = Uint8List(1 + nick.length + 1)
      ..[0] = nick.length
      ..setRange(1, 1 + nick.length, nick)
      ..[1 + nick.length] = txActive ? 1 : 0;
    return _wrap(
      type: PacketType.presence,
      body: body,
      channel: channel,
      seq: seq,
      senderId: senderId,
      timestampMs: timestampMs,
    );
  }

  /// TX_START 패킷 생성.
  Uint8List encodeTxStart({
    required String nickname,
    required int talkMs,
    required int channel,
    required int seq,
    required String senderId,
    required int timestampMs,
  }) {
    final nick = utf8.encode(nickname);
    if (nick.length > _maxNicknameLen) {
      throw ArgumentError('닉네임이 $_maxNicknameLen바이트를 초과');
    }
    final body = Uint8List(1 + nick.length + 2)
      ..[0] = nick.length
      ..setRange(1, 1 + nick.length, nick);
    ByteData.sublistView(body)
        .setUint16(1 + nick.length, talkMs, Endian.little);
    return _wrap(
      type: PacketType.txStart,
      body: body,
      channel: channel,
      seq: seq,
      senderId: senderId,
      timestampMs: timestampMs,
    );
  }

  /// TX_END 패킷 생성.
  Uint8List encodeTxEnd({
    required String nickname,
    required int channel,
    required int seq,
    required String senderId,
    required int timestampMs,
  }) {
    final nick = utf8.encode(nickname);
    if (nick.length > _maxNicknameLen) {
      throw ArgumentError('닉네임이 $_maxNicknameLen바이트를 초과');
    }
    final body = Uint8List(1 + nick.length)
      ..[0] = nick.length
      ..setRange(1, 1 + nick.length, nick);
    return _wrap(
      type: PacketType.txEnd,
      body: body,
      channel: channel,
      seq: seq,
      senderId: senderId,
      timestampMs: timestampMs,
    );
  }

  /// AUDIO 패킷 생성. PCM16 LE raw를 그대로 body로 사용.
  Uint8List encodeAudio({
    required Uint8List pcm,
    required int channel,
    required int seq,
    required String senderId,
    required int timestampMs,
  }) {
    return _wrap(
      type: PacketType.audio,
      body: pcm,
      channel: channel,
      seq: seq,
      senderId: senderId,
      timestampMs: timestampMs,
    );
  }

  Uint8List _wrap({
    required PacketType type,
    required Uint8List body,
    required int channel,
    required int seq,
    required String senderId,
    required int timestampMs,
  }) {
    final sender = uuidToBytes(senderId);
    final data = Uint8List(RadioHeader.kSize + body.length);
    final bd = ByteData.sublistView(data);
    bd.setUint16(0, AppConstants.kMagic, Endian.little);
    bd.setUint8(2, AppConstants.kProtocolVersion);
    bd.setUint8(3, type.value);
    bd.setUint16(4, RadioHeader.kSize, Endian.little);
    bd.setUint16(6, body.length, Endian.little);
    bd.setUint32(8, seq, Endian.little);
    bd.setUint8(12, channel);
    bd.setUint8(13, AudioCodec.pcmS16Le16kMono.value);
    bd.setUint16(14, AppConstants.kSampleRate, Endian.little);
    bd.setUint64(16, timestampMs, Endian.little);
    data.setRange(24, 40, sender);
    data.setRange(40, data.length, body);
    return data;
  }

  // ── 디코딩 ──────────────────────────────────────────────

  /// 잘못된 패킷(magic/version/길이/채널 불일치)이면 null.
  DecodedPacket? decode(Uint8List data) {
    if (data.length < RadioHeader.kSize) return null;
    final bd = ByteData.sublistView(data);
    if (bd.getUint16(0, Endian.little) != AppConstants.kMagic) return null;
    if (bd.getUint8(2) != AppConstants.kProtocolVersion) return null;
    final type = PacketType.fromValue(bd.getUint8(3));
    if (type == null) return null;
    final headerLen = bd.getUint16(4, Endian.little);
    if (headerLen < RadioHeader.kSize) return null;
    final payloadLen = bd.getUint16(6, Endian.little);
    if (data.length < headerLen + payloadLen) return null;
    final channel = bd.getUint8(12);
    if (channel < 1 || channel > AppConstants.kChannelCount) return null;

    return DecodedPacket(
      header: RadioHeader(
        type: type,
        headerLen: headerLen,
        payloadLen: payloadLen,
        seq: bd.getUint32(8, Endian.little),
        channel: channel,
        codec: bd.getUint8(13),
        sampleRate: bd.getUint16(14, Endian.little),
        timestampMs: bd.getUint64(16, Endian.little),
        senderId: Uint8List.fromList(data.sublist(24, 40)),
      ),
      body: Uint8List.fromList(data.sublist(headerLen, headerLen + payloadLen)),
    );
  }

  PresenceBody decodePresence(Uint8List body) {
    final bd = ByteData.sublistView(body);
    final nickLen = bd.getUint8(0);
    if (body.length < 2 + nickLen) {
      throw FormatException('PRESENCE body 길이 불일치');
    }
    final nick = utf8.decode(body.sublist(1, 1 + nickLen));
    final txActive = bd.getUint8(1 + nickLen) != 0;
    return PresenceBody(nickname: nick, txActive: txActive);
  }

  TxStartBody decodeTxStart(Uint8List body) {
    final bd = ByteData.sublistView(body);
    final nickLen = bd.getUint8(0);
    if (body.length < 3 + nickLen) {
      throw FormatException('TX_START body 길이 불일치');
    }
    final nick = utf8.decode(body.sublist(1, 1 + nickLen));
    final talkMs = bd.getUint16(1 + nickLen, Endian.little);
    return TxStartBody(nickname: nick, talkMs: talkMs);
  }

  TxEndBody decodeTxEnd(Uint8List body) {
    final bd = ByteData.sublistView(body);
    final nickLen = bd.getUint8(0);
    if (body.length < 1 + nickLen) {
      throw FormatException('TX_END body 길이 불일치');
    }
    final nick = utf8.decode(body.sublist(1, 1 + nickLen));
    return TxEndBody(nickname: nick);
  }
}
