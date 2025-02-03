import 'package:flutter/material.dart';
import 'package:reellearning_fe/src/core/routes/app_router.dart';
import 'settings/settings_controller.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.settingsController});

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      title: 'ReelLearning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}