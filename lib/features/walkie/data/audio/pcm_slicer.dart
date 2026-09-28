/// PCM 청크를 고정 크기 프레임으로 절단하는 슬라이서 (Flutter 비의존 순수 Dart).
///
/// record의 `pcmStream`은 청크 크기가 불규칙하므로 640 B(20 ms@16 kHz mono s16le)
/// 프레임으로 모아낸다. 마지막의 640 B 미만 꼬리는 보관했다가 다음 청크와 이어 붙인다.
library;

import 'dart:typed_data';

class PcmSlicer {
  PcmSlicer({this.frameSize = 640});

  final int frameSize;

  final List<int> _pending = [];

  /// 누적 바이트 수.
  int get pendingBytes => _pending.length;

  /// [chunk]를 누적하고 완성된 프레임 목록을 반환한다.
  List<Uint8List> push(List<int> chunk) {
    _pending.addAll(chunk);
    final frames = <Uint8List>[];
    while (_pending.length >= frameSize) {
      final frame = Uint8List(frameSize);
      frame.setRange(0, frameSize, _pending);
      _pending.removeRange(0, frameSize);
      frames.add(frame);
    }
    return frames;
  }

  /// 남은 꼬리를 비우고 비운다. [dropTail]이 false면 마지막 잔여 프레임을 반환한다.
  Uint8List? flush({bool dropTail = true}) {
    if (_pending.isEmpty) return null;
    final tail = Uint8List.fromList(_pending);
    _pending.clear();
    return dropTail ? null : tail;
  }

  void clear() => _pending.clear();
}
