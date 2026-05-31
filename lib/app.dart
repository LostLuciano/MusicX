import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'widgets/phone_frame_layout.dart';
import 'state/studio_settings_controller.dart';

class MusicStemStudioApp extends StatelessWidget {
  const MusicStemStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Provider.of<StudioSettingsController>(context);
    final primaryColor = Color(settingsController.settings.themeColorValue);

    return MaterialApp(
      title: 'Music Stem Studio',
      theme: AppTheme.getDarkTheme(primaryColor).copyWith(
        scaffoldBackgroundColor: settingsController.settings.uiStyle == 1
            ? Colors.transparent
            : const Color(0xFF0F0C1B),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return PhoneFrameLayout(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
