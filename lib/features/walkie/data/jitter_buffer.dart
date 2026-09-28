/// 송신 순서 복원·중복 폐기·경량 PLC를 담당하는 지터 버퍼 (순수 Dart).
///
/// - 버스트 시작: 첫 프레임 도착 후 [targetMs]가 경과해야 재생 시작(워밍업).
/// - seq 역전/중복 → `duplicateDropped` 폐기, out-of-order는 순서 복원.
/// - 순서상 공백(갭) → 마지막 프레임 홀드(PLC). 연속 [maxReplayGapFrames]
///   이상 유실 시 홀 스킵. [maxDropMs]만큼 새 프레임이 없으면 [shouldStop].
library;

import 'dart:typed_data';

class JitterBuffer {
  JitterBuffer({
    this.targetMs = 60,
    this.maxDropMs = 120,
    this.maxReplayGapFrames = 6,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? _defaultClock;

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  final int targetMs;
  final int maxDropMs;
  final int maxReplayGapFrames;
  final int Function() _nowMs;

  final Map<int, Uint8List> _queue = {};
  int? _nextSeq;
  int _startSeq = 0;
  int? _startArrivalMs;
  Uint8List? _lastSample;
  int _lastOfferMs = 0;

  int _duplicateDropped = 0;
  int _outOfOrderDropped = 0;
  int _plcInserted = 0;
  int _holeSkipped = 0;

  /// 버퍼에 재생 대기가 남아 있는지.
  bool get hasPending => _queue.isNotEmpty;

  /// 버스트 진행 중(워밍업 포함)인지.
  bool get isActive => _nextSeq != null || _queue.isNotEmpty;

  /// 재생 대기 프레임 수.
  int get bufferedFrames => _queue.length;

  /// 폐기/보정 통계.
  int get duplicateDropped => _duplicateDropped;
  int get outOfOrderDropped => _outOfOrderDropped;
  int get plcInserted => _plcInserted;
  int get holeSkipped => _holeSkipped;

  /// [seq] 프레임을 버퍼에 담는다. 중복/역전은 조용히 폐기.
  void offer(int seq, Uint8List pcm) {
    final now = _nowMs();
    _lastOfferMs = now;
    if (_nextSeq == null) {
      if (_queue.isEmpty) {
        _startSeq = seq;
      } else if (seq < _startSeq) {
        _outOfOrderDropped++;
        return;
      }
      if (_queue.containsKey(seq)) {
        _duplicateDropped++;
        return;
      }
      _queue[seq] = pcm;
      _startArrivalMs ??= now;
      return;
    }
    if (seq < _nextSeq! || _queue.containsKey(seq)) {
      _duplicateDropped++;
      return;
    }
    _queue[seq] = pcm;
  }

  /// 지금 재생 가능한 프레임을 seq 순으로 반환한다.
  List<Uint8List> drain() {
    if (_nextSeq == null) {
      // 워밍업: 첫 도착 + targetMs 경과 전에는 대기.
      if (_queue.isEmpty) return const [];
      final firstArrival = _startArrivalMs ?? _nowMs();
      if (_nowMs() - firstArrival < targetMs) return const [];
      _nextSeq = _startSeq;
    }

    final out = <Uint8List>[];
    while (true) {
      final frame = _queue.remove(_nextSeq!);
      if (frame != null) {
        _lastSample = frame;
        out.add(frame);
        _nextSeq = _nextSeq! + 1;
        continue;
      }
      // 다음 프레임이 아직 없다: 남아 있는 최소 seq로 갭을 판단.
      int? minLater;
      for (final k in _queue.keys) {
        if (k > _nextSeq! && (minLater == null || k < minLater)) {
          minLater = k;
        }
      }
      if (minLater == null) break;
      final gap = minLater - _nextSeq!;
      if (gap <= maxReplayGapFrames && _lastSample != null) {
        // 경미한 갭: 마지막 프레임 홀드(PLC)로 채운다.
        _plcInserted += gap;
        for (var i = 0; i < gap; i++) {
          out.add(_lastSample!);
          _nextSeq = _nextSeq! + 1;
        }
        continue;
      }
      // 심한 갭: 홀 스킵.
      _holeSkipped++;
      _nextSeq = minLater;
    }
    return out;
  }

  /// [maxDropMs]보다 새 프레임이 없으면 true (다음 버스트에서 reset 전까지 유지).
  bool shouldStop({int? nowMs}) {
    if (_nextSeq == null) return false;
    final now = nowMs ?? _nowMs();
    return now - _lastOfferMs > maxDropMs;
  }

  /// 버스트 경계(발화 불연속)에서 호출: 큐·재생 지표 초기화.
  void reset() {
    _queue.clear();
    _nextSeq = null;
    _startArrivalMs = null;
    _lastSample = null;
    _lastOfferMs = 0;
  }

  /// 통계 초기화 (선택).
  void resetStats() {
    _duplicateDropped = 0;
    _outOfOrderDropped = 0;
    _plcInserted = 0;
    _holeSkipped = 0;
  }
}
