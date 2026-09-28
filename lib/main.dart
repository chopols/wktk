import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 무전기처럼 화면이 꺼지지 않도록 유지 (사용자가 설정에서 끌 수 있음)
  await WakelockPlus.enable();
  runApp(const ProviderScope(child: WktkApp()));
}

class WktkApp extends ConsumerWidget {
  const WktkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      themeModeControllerProvider.select((s) => s.value ?? AppThemeMode.dark),
    );
    return MaterialApp(
      title: 'WKTK 무전기',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: const AppGate(),
    );
  }
}
