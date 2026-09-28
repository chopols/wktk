/// 효과음 재생 (flutter_soloud, 앱 전용).
///
/// WAV는 `tool/gen_sounds.dart`로 오프라인 생성되어 `assets/sounds/`에 있고,
/// pubspec assets에 등록되어 있다. 토글(`enabled`)은 UI 상태를 따른다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class SoundEffects {
  SoundEffects({this.enabled = true});

  bool enabled;

  AudioSource? _roger;
  AudioSource? _squelch;
  AudioSource? _denied;

  Future<void> init() async {
    try {
      _roger = await SoLoud.instance.loadAsset('assets/sounds/roger_beep.wav');
      _squelch = await SoLoud.instance.loadAsset(
        'assets/sounds/squelch_tone.wav',
      );
      _denied = await SoLoud.instance.loadAsset(
        'assets/sounds/denied_tone.wav',
      );
    } catch (e) {
      debugPrint('사운드 로드 실패: $e');
    }
  }

  /// PTT 시작/종료 비프.
  void rogerBeep() => _play(_roger, volume: 0.45);

  /// 수신 시작 블립.
  void squelch() => _play(_squelch, volume: 0.3);

  /// 채널 사용 중/충돌 거부 버즈.
  void denied() => _play(_denied, volume: 0.5);

  void _play(AudioSource? source, {required double volume}) {
    if (!enabled || source == null) return;
    try {
      SoLoud.instance.play(source, volume: volume);
    } catch (_) {
      // 재생 실패는 무시(효과음이 핵심 경로를 방해하지 않도록)
    }
  }
}
