import 'package:flutter/material.dart';
import 'asteroid.dart';

class GamePainter extends CustomPainter {
  final List<Asteroid> asteroids;
  GamePainter(this.asteroids);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050914), Colors.black],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    final starPaint = Paint()..color = Colors.white.withOpacity(0.12);
    for (int i = 0; i < 120; i++) {
      canvas.drawCircle(
        Offset((i * 97 % 997) / 997 * w, (i * 223 % 991) / 991 * h),
        (i % 3 + 1) * 0.6,
        starPaint,
      );
    }

    final asteroidPaint = Paint()..color = Colors.white.withOpacity(0.18);
    for (final a in asteroids) {
      canvas.drawCircle(Offset(a.x * w, a.y * h), a.rPx, asteroidPaint);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
