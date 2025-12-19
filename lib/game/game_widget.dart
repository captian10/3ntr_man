import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';
import 'game_painter.dart';
import 'asteroid.dart';

class GameWidget extends StatefulWidget {
  const GameWidget({super.key});

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final Random _rng = Random();
  final List<Asteroid> _asteroids = [];
  final AudioPlayer _audio = AudioPlayer();

  double _w = 0, _h = 0;
  Offset _player = const Offset(0.5, 0.82);
  double _playerRadius = 22;
  double _targetX = 0.5;
  double _tilt = 0;
  double _floatTime = 0;

  double _spawnTimer = 0;
  double _spawnEvery = 0.75;
  double _difficultyTimer = 0;

  double _shakeTime = 0;
  double _shakeIntensity = 0;

  int score = 0;
  int bestScore = 0; // keep as 0 for now or reconnect later

  Future<void> _playSound(String file) async {
    await _audio.setVolume(AppSettings.volume);
    await _audio.stop();
    await _audio.play(AssetSource('audio/$file'));
  }

  void _hapticLight() => HapticFeedback.lightImpact();
  void _hapticHeavy() => HapticFeedback.heavyImpact();

  @override
  void initState() {
    super.initState();

    _ticker = createTicker((elapsed) {
      final dt = (_last == Duration.zero)
          ? 0.016
          : (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;

      if (_shakeTime > 0) {
        _shakeTime -= dt;
        if (_shakeTime <= 0) _shakeIntensity = 0;
      }

      _update(dt.clamp(0.0, 0.05));
      setState(() {});
    });

    _ticker.start();

    // start sound
    _playSound('start.wav');
    _hapticLight();
  }

  @override
  void dispose() {
    _audio.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _gameOver() {
    _shakeTime = 0.25;
    _shakeIntensity = 14;

    _playSound('hit.wav');
    _hapticHeavy();

    // Restart after hit (simple). Later you can show Game Over overlay.
    Future.delayed(const Duration(milliseconds: 500), () {
      _reset();
    });
  }

  void _reset() {
    _asteroids.clear();
    score = 0;
    _targetX = 0.5;
    _spawnTimer = 0;
    _spawnEvery = 0.75;
    _difficultyTimer = 0;
  }

  void _update(double dt) {
    _floatTime += dt;

    final speed = 9.0;
    final newX = _lerp(_player.dx, _targetX, speed * dt);
    final floatOffset = sin(_floatTime * 4) * 0.004;

    _player = Offset(newX.clamp(0.08, 0.92), 0.82 + floatOffset);
    _tilt = (_targetX - _player.dx).clamp(-0.15, 0.15);

    _spawnTimer += dt;
    if (_spawnTimer >= _spawnEvery) {
      _spawnTimer = 0;
      _spawnAsteroid();
    }

    _difficultyTimer += dt;
    if (_difficultyTimer >= 2.2) {
      _difficultyTimer = 0;
      _spawnEvery = max(0.32, _spawnEvery * 0.96);
      for (final a in _asteroids) {
        a.speed *= 1.02;
      }
    }

    for (final a in _asteroids) {
      a.y += a.speed * dt;
      a.x += a.drift * dt;
    }

    _asteroids.removeWhere((a) {
      if (a.y > 1.2) {
        score++;
        return true;
      }
      return false;
    });

    final p = Offset(_player.dx * _w, _player.dy * _h);
    for (final a in _asteroids) {
      final c = Offset(a.x * _w, a.y * _h);
      if ((p - c).distance <= (_playerRadius * 0.65 + a.rPx)) {
        _gameOver();
        break;
      }
    }
  }

  void _spawnAsteroid() {
    _asteroids.add(Asteroid(
      x: 0.1 + _rng.nextDouble() * 0.8,
      y: -0.2,
      r: 12 + _rng.nextDouble() * 16,
      speed: 0.5 + _rng.nextDouble() * 0.6,
      drift: (_rng.nextDouble() - 0.5) * 0.15,
    ));
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _w = c.maxWidth;
      _h = c.maxHeight;
      _playerRadius = min(_w, _h) * 0.045;

      for (final a in _asteroids) {
        a.rPx = a.r / 40 * min(_w, _h) * 0.09;
      }

      final shake = _shakeTime > 0
          ? Offset(
              (_rng.nextDouble() - 0.5) * _shakeIntensity,
              (_rng.nextDouble() - 0.5) * _shakeIntensity,
            )
          : Offset.zero;

      return Transform.translate(
        offset: shake,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            _targetX = (details.localPosition.dx / _w).clamp(0.05, 0.95);
          },
          child: Stack(
            children: [
              CustomPaint(
                painter: GamePainter(_asteroids),
                child: const SizedBox.expand(),
              ),

              Positioned(
                left: (_player.dx * _w) - _playerRadius * 1.5,
                top: (_player.dy * _h) - _playerRadius * 1.5,
                child: Transform.rotate(
                  angle: _tilt,
                  child: Image.asset(
                    'assets/images/player.png',
                    width: _playerRadius * 3,
                    height: _playerRadius * 3,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _chip('Score: $score'),
                      const SizedBox(width: 8),
                      _chip('Vol: ${(AppSettings.volume * 100).round()}%'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t),
      );
}
