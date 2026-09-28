/// 간단한 로컬 저장소 래퍼(shared_preferences). 설정 키 상수 포함.
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract final class AppPrefs {
  static const _kOnboardingDone = 'onboarding_done';
  static const _kNickname = 'nickname';
  static const _kDefaultChannel = 'default_channel';
  static const _kVolume = 'volume';
  static const _kEffectsEnabled = 'effects_enabled';
  static const _kHapticsEnabled = 'haptics_enabled';
  static const _kVoxEnabled = 'vox_enabled';
  static const _kNoiseGateEnabled = 'noise_gate_enabled';
  static const _kThemeMode = 'theme_mode';

  static Future<bool> onboardingDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kOnboardingDone) ?? false;
  }

  static Future<void> setOnboardingDone(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboardingDone, value);
  }

  static Future<String> nickname() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kNickname) ?? '';
  }

  static Future<void> setNickname(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kNickname, value);
  }

  static Future<int> defaultChannel() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kDefaultChannel) ?? 1;
  }

  static Future<void> setDefaultChannel(int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kDefaultChannel, value);
  }

  static Future<double> volume() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_kVolume) ?? 0.7;
  }

  static Future<void> setVolume(double value) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kVolume, value);
  }

  static Future<bool> effectsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEffectsEnabled) ?? true;
  }

  static Future<void> setEffectsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEffectsEnabled, value);
  }

  static Future<bool> hapticsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kHapticsEnabled) ?? true;
  }

  static Future<void> setHapticsEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHapticsEnabled, value);
  }

  static Future<bool> voxEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kVoxEnabled) ?? false;
  }

  static Future<void> setVoxEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVoxEnabled, value);
  }

  static Future<bool> noiseGateEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kNoiseGateEnabled) ?? true;
  }

  static Future<void> setNoiseGateEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNoiseGateEnabled, value);
  }

  /// 테마 모드 문자열 ('dark' | 'light' | 'system'), 기본 'dark'.
  static Future<String> themeMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kThemeMode) ?? 'dark';
  }

  static Future<void> setThemeMode(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, value);
  }
}
