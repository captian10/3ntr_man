import 'package:flutter/material.dart';
import '../game/game_widget.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: GameWidget(),
      ),
    );
  }
}
