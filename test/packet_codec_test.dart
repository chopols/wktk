import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wktk/core/network/packet_codec.dart';
import 'package:wktk/core/network/packet.dart';

void main() {
  const codec = PacketCodec();
  const senderId = '29ab7f2a-9b5c-4a3e-b0d1-c2f6a1e3d4b5';

  group('uuid 헬퍼', () {
    test('bytes → 문자열 왕복', () {
      final bytes = uuidToBytes(senderId);
      expect(bytes.length, 16);
      expect(uuidFromBytes(bytes), senderId);
    });

    test('잘못된 형식은 throw', () {
      expect(() => uuidToBytes('짧은-id'), throwsArgumentError);
      expect(
        () => uuidToBytes(senderId.replaceAll('-', 'x')),
        throwsArgumentError,
      );
    });
  });

  group('encode/decode 왕복', () {
    test('PRESENCE', () {
      final raw = codec.encodePresence(
        nickname: '지훈',
        txActive: false,
        channel: 3,
        seq: 7,
        senderId: senderId,
        timestampMs: 987654321,
      );
      final dec = codec.decode(raw);
      expect(dec, isNotNull);
      final h = dec!.header;
      expect(h.type, PacketType.presence);
      expect(h.channel, 3);
      expect(h.seq, 7);
      expect(h.timestampMs, 987654321);
      expect(uuidFromBytes(h.senderId), senderId);
      final body = codec.decodePresence(dec.body);
      expect(body.nickname, '지훈');
      expect(body.txActive, isFalse);
    });

    test('TX_START', () {
      final raw = codec.encodeTxStart(
        nickname: '영희',
        talkMs: 1203,
        channel: 1,
        seq: 1,
        senderId: senderId,
        timestampMs: 1,
      );
      final dec = codec.decode(raw);
      final body = codec.decodeTxStart(dec!.body);
      expect(body.nickname, '영희');
      expect(body.talkMs, 1203);
    });

    test('TX_END', () {
      final raw = codec.encodeTxEnd(
        nickname: '영희',
        channel: 1,
        seq: 2,
        senderId: senderId,
        timestampMs: 2,
      );
      final dec = codec.decode(raw);
      final body = codec.decodeTxEnd(dec!.body);
      expect(body.nickname, '영희');
    });

    test('AUDIO (큰 페이로드)', () {
      final pcm = Uint8List(1280);
      for (var i = 0; i < pcm.length; i++) {
        pcm[i] = (i * 31) & 0xFF;
      }
      final raw = codec.encodeAudio(
        pcm: pcm,
        channel: 1,
        seq: 42,
        senderId: senderId,
        timestampMs: 1000,
      );
      expect(raw.length, RadioHeader.kSize + pcm.length);
      final dec = codec.decode(raw);
      expect(dec!, isNotNull);
      expect(dec.header.payloadLen, pcm.length);
      expect(dec.body, pcm);
    });
  });

  group('검증/거부', () {
    test('마법값 오류 폐기', () {
      final raw = codec.encodePresence(
        nickname: 'A',
        txActive: false,
        channel: 1,
        seq: 1,
        senderId: senderId,
        timestampMs: 1,
      );
      raw[0] = 0x00;
      raw[1] = 0x00;
      expect(codec.decode(raw), isNull);
    });

    test('버전 오류 폐기', () {
      final raw = codec.encodePresence(
        nickname: 'A',
        txActive: false,
        channel: 1,
        seq: 1,
        senderId: senderId,
        timestampMs: 1,
      );
      raw[2] = 99;
      expect(codec.decode(raw), isNull);
    });

    test('헤더보다 짧은 데이터 폐기', () {
      expect(codec.decode(Uint8List(5)), isNull);
    });

    test('채널 범위 밖 폐기', () {
      final raw = codec.encodePresence(
        nickname: 'A',
        txActive: false,
        channel: 16,
        seq: 1,
        senderId: senderId,
        timestampMs: 1,
      );
      // 수동으로 채널을 0으로 조작(encode는 1..16 검증 안 함).
      final bd = ByteData.sublistView(raw);
      final good = bd.getUint8(12);
      bd.setUint8(12, 0);
      try {
        expect(codec.decode(raw), isNull);
      } finally {
        bd.setUint8(12, good);
      }
    });

    test('닉네임 32바이트 초과 throw', () {
      expect(
        () => codec.encodePresence(
          nickname: '가' * 20, // UTF-8 3바이트 → 60바이트
          txActive: false,
          channel: 1,
          seq: 1,
          senderId: senderId,
          timestampMs: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
