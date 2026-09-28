/// 마이크 PCM 캡처 (record 플러그인, 앱 전용).
///
/// 16 kHz / mono / PCM16 LE 스트림을 방출한다. 순수 Dart 계층과 방출 경계는
/// `TransceiverService`에 반영되어 있고 이 클래스는 플러그인 호출만 담당.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../../../core/constants/app_constants.dart';

class AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool _recording = false;

  bool get isRecording => _recording;

  /// 녹음 시작. 방출된 프레임은 [onPcm]으로 전달된다.
  Future<void> start({void Function(Uint8List chunk)? onPcm}) async {
    if (_recording) return;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.kSampleRate,
        numChannels: AppConstants.kChannels,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    _recording = true;
    _sub = stream.listen(onPcm);
  }

  /// 녹음 중지. 미완결 바이트는 버린다.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _recording = false;
    try {
      await _recorder.stop();
    } catch (_) {
      // 이미 중지됨 등 무시
    }
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _recorder.dispose();
    } catch (_) {
      // 무시
    }
  }
}
