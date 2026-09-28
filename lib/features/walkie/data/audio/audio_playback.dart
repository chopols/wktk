/// 수신 PCM 재생 (flutter_soloud, 앱 전용).
///
/// 16 kHz / mono / PCM16 LE 버퍼 스트림을 1회 `play()`로 열고 수신 프레임을
/// `addAudioDataStream`으로 채운다. 버스트 사이 유휴 시 자동으로 재생이 멈추고
/// 재개되며, 새 버스트 시작 시 `reset()`으로 잔여 버퍼를 비워 번짐을 방지한다.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../../core/constants/app_constants.dart';

class AudioPlayback {
  AudioSource? _source;
  SoundHandle? _handle;
  double _volume = AppConstants.kDefaultVolume;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init({double volume = AppConstants.kDefaultVolume}) async {
    if (_ready) return;
    await SoLoud.instance.init();
    _volume = volume;
    _source = SoLoud.instance.setBufferStream(
      sampleRate: AppConstants.kSampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
      bufferingType: BufferingType.preserved,
      bufferingTimeNeeds: 0.06, // ~60 ms — 무전기 지연 예산(Step 3 계획)
      maxBufferSizeBytes: 3 * 1024 * 1024, // 약 90초(16k mono s16)
    );
    _handle = SoLoud.instance.play(_source!, volume: _volume);
    _ready = true;
  }

  /// 새 버스트 시작 시 남은 버퍼를 비운다.
  void reset() {
    if (!_ready || _source == null) return;
    try {
      SoLoud.instance.resetBufferStream(_source!);
    } catch (_) {
      // 무시
    }
  }

  /// PCM16 LE 프레임을 재생 버퍼에 추가.
  void feed(Uint8List pcm) {
    if (!_ready || _source == null) return;
    try {
      SoLoud.instance.addAudioDataStream(_source!, pcm);
    } catch (e) {
      debugPrint('AudioPlayback.feed 오류: $e');
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (_ready && _handle != null) {
      SoLoud.instance.setVolume(_handle!, _volume);
    }
  }

  Future<void> dispose() async {
    if (!_ready) return;
    _ready = false;
    try {
      if (_source != null) {
        SoLoud.instance.resetBufferStream(_source!);
      }
      SoLoud.instance.deinit();
    } catch (_) {
      // 무시
    }
    _source = null;
    _handle = null;
  }
}

/// PCM16 LE 바이트의 RMS(0.0~1.0) 추정 (신호 레벨 미터용).
double pcm16Rms(Uint8List pcm) {
  if (pcm.isEmpty) return 0.0;
  var sum = 0.0;
  final n = pcm.length ~/ 2;
  final bd = ByteData.sublistView(pcm);
  for (var i = 0; i < n; i++) {
    final s = bd.getInt16(i * 2, Endian.little) / 32768.0;
    sum += s * s;
  }
  return (math.sqrt(sum / n)).clamp(0.0, 1.0);
}
