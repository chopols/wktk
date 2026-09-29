/// 설정 화면.
///
/// Step 6: 닉네임/기본 채널/볼륨/효과음/햅틱/VOX/노이즈 게이트/테마 + 연결 권한.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme.dart';
import '../../../core/utils/kv_store.dart';
import '../../walkie/presentation/walkie_controller.dart';
import '../settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nickCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final nick = await AppPrefs.nickname();
    if (!mounted || _nickCtrl.text.isNotEmpty) return;
    setState(() => _nickCtrl.text = nick);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walkieControllerProvider);
    final controller = ref.read(walkieControllerProvider.notifier);
    final themeVm =
        ref.watch(themeModeControllerProvider).value ?? AppThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SectionHeader('프로필'),
          ListTile(
            leading: const Icon(Icons.badge_outlined, color: AppColors.accent),
            title: const Text('닉네임'),
            subtitle: const Text('상대에게 표시될 이름'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nickCtrl,
                    maxLength: 12,
                    decoration: const InputDecoration(
                      hintText: '나',
                      counterText: '',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveNickname,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF1B1205),
                  ),
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader('기본값'),
          ListTile(
            leading: const Icon(Icons.tune, color: AppColors.accent),
            title: const Text('기본 채널'),
            subtitle: Text('현재 채널 ${state.channel} · 시작 시 이 채널에서 열립니다'),
            trailing: DropdownButton<int>(
              value: state.channel,
              underline: const SizedBox.shrink(),
              items: [
                for (var c = 1; c <= 16; c++)
                  DropdownMenuItem<int>(
                    value: c,
                    child: Text(
                      c.toString().padLeft(2, '0'),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) controller.setChannel(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up, color: AppColors.accent),
            title: const Text('재생 볼륨'),
            subtitle: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: state.volume,
                    onChanged: controller.setVolume,
                  ),
                ),
                Text(
                  '${(state.volume * 100).round()}%',
                  style: const TextStyle(
                    color: AppColors.textMid,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader('기능'),
          SwitchListTile(
            secondary: const Icon(Icons.toll, color: AppColors.accent),
            title: const Text('효과음'),
            subtitle: const Text('roger beep · 스퀠치 · 거부음'),
            value: state.effectsEnabled,
            onChanged: controller.setEffectsEnabled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration, color: AppColors.accent),
            title: const Text('햅틱'),
            subtitle: const Text('PTT · 노브 · 거부 시 진동'),
            value: state.hapticsEnabled,
            onChanged: controller.setHapticsEnabled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mic_none, color: AppColors.accent),
            title: const Text('VOX'),
            subtitle: const Text('PTT 없이 목소리로 자동 송신'),
            value: state.voxEnabled,
            onChanged: controller.setVoxEnabled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.hearing, color: AppColors.accent),
            title: const Text('수신 노이즈 게이트'),
            subtitle: const Text('작은 잡음 프레임을 침묵 처리'),
            value: state.noiseGateEnabled,
            onChanged: controller.setNoiseGateEnabled,
          ),
          const Divider(),
          _SectionHeader('화면'),
          RadioGroup<AppThemeMode>(
            groupValue: themeVm,
            onChanged: _setTheme,
            child: const Column(
              children: [
                RadioListTile<AppThemeMode>(
                  secondary: Icon(Icons.dark_mode, color: AppColors.accent),
                  title: Text('다크'),
                  value: AppThemeMode.dark,
                ),
                RadioListTile<AppThemeMode>(
                  secondary: Icon(Icons.light_mode, color: AppColors.accent),
                  title: Text('라이트'),
                  value: AppThemeMode.light,
                ),
                RadioListTile<AppThemeMode>(
                  secondary: Icon(
                    Icons.brightness_auto,
                    color: AppColors.accent,
                  ),
                  title: Text('시스템'),
                  value: AppThemeMode.system,
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader('전원 · 백그라운드'),
          ListTile(
            leading: Icon(
              Icons.power_settings_new,
              color: state.powerOn ? AppColors.txRed : AppColors.textLow,
            ),
            title: Text('전원 ${state.powerOn ? '켜짐' : '꺼짐'}'),
            subtitle: const Text('꺼짐 시 앱 프로세스가 완전히 종료됩니다'),
            trailing: const Text('상단 전원 버튼'),
          ),
          FutureBuilder<PermissionStatus>(
            future: Permission.notification.status,
            builder: (context, snap) {
              final status = snap.data;
              final label = switch (status) {
                PermissionStatus.granted => '허용됨',
                PermissionStatus.denied => '거부됨',
                PermissionStatus.permanentlyDenied => '차단됨',
                PermissionStatus.limited => '제한적 허용',
                _ => '확인 중…',
              };
              return ListTile(
                leading: Icon(
                  Icons.notifications_active_outlined,
                  color: status?.isGranted == true
                      ? AppColors.rxGreen
                      : AppColors.textLow,
                ),
                title: Text('알림 ($label)'),
                subtitle: const Text('전원 상태와 상대 호출 알림에 필요합니다'),
                trailing: TextButton(
                  onPressed: openAppSettings,
                  child: const Text('앱 설정 열기'),
                ),
              );
            },
          ),
          const Divider(),
          _SectionHeader('연결 권한'),
          FutureBuilder<PermissionStatus>(
            future: Permission.microphone.status,
            builder: (context, snap) {
              final status = snap.data;
              final label = switch (status) {
                PermissionStatus.granted => '허용됨',
                PermissionStatus.denied => '거부됨',
                PermissionStatus.permanentlyDenied => '차단됨',
                PermissionStatus.limited => '제한적 허용',
                _ => '확인 중…',
              };
              return ListTile(
                leading: Icon(
                  Icons.mic,
                  color: status?.isGranted == true
                      ? AppColors.rxGreen
                      : AppColors.txRed,
                ),
                title: Text('마이크 ($label)'),
                subtitle: const Text('송신 시 필요'),
                trailing: TextButton(
                  onPressed: openAppSettings,
                  child: const Text('앱 설정 열기'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _setTheme(AppThemeMode? mode) {
    if (mode != null) {
      ref.read(themeModeControllerProvider.notifier).set(mode);
    }
  }

  void _saveNickname() {
    final text = _nickCtrl.text.trim();
    ref.read(walkieControllerProvider.notifier).setNickname(text);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('닉네임을 저장했습니다')));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
