import 'package:flutter/material.dart';
import 'screens/main_menu_screen.dart';

class SpaceDodgerApp extends StatelessWidget {
  const SpaceDodgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MainMenuScreen(),
    );
  }
}
