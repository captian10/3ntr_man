import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/menu_bg.png'),
            fit: BoxFit.cover, // fills the screen
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '3ntr man',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              _btn(
                text: 'START',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GameScreen()),
                ),
              ),
              _btn(
                text: 'SETTINGS',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _btn(text: 'EXIT', onTap: () => SystemNavigator.pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn({required String text, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 230,
        height: 48,
        child: FilledButton(
          onPressed: onTap,
          child: Text(text, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
