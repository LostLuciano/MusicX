import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'state/project_controller.dart';
import 'state/profile_controller.dart';
import 'state/studio_settings_controller.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectController()..init()),
        ChangeNotifierProvider(create: (_) => ProfileController()..init()),
        ChangeNotifierProvider(create: (_) => StudioSettingsController()..init()),
      ],
      child: const MusicStemStudioApp(),
    ),
  );
}
