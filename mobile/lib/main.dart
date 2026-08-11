import 'package:flutter/material.dart';

import 'services/app_settings.dart';
import 'services/sync_controller.dart';
import 'ui/main_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SyncController.init(); // 读配置并启动云同步（未配置则跳过）
  AppTheme.apply(AppSettings.themeDark); // 应用暗黑偏好
  runApp(const MemoApp());
}

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.darkNotifier,
      builder: (context, dark, _) => MaterialApp(
        title: 'MEMO',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(darkMode: true),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const MainShell(),
      ),
    );
  }
}
