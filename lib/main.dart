import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _Settings.load();
  runApp(const SpaceDodgerApp());
}

/* =========================================================
   SETTINGS (VOLUME + HIGHSCORE)
========================================================= */

class _Settings {
  static double volume = 1.0;
  static int highScore = 0;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    volume = prefs.getDouble('volume') ?? 1.0;
    highScore = prefs.getInt('highScore') ?? 0;
  }

  static Future<void> saveVolume(double v) async {
    volume = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', v);
  }

  static Future<void> saveHighScore(int v) async {
    highScore = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', v);
  }
}

/* =========================================================
   APP ROOT
========================================================= */

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

/* =========================================================
   MAIN MENU (WITH MENU MUSIC)
========================================================= */

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with WidgetsBindingObserver {
  final AudioPlayer _menuMusic = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMenuMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _menuMusic.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopMenuMusic();
    } else if (state == AppLifecycleState.resumed) {
      _startMenuMusic();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _startMenuMusic() async {
    try {
      await _menuMusic.setReleaseMode(ReleaseMode.loop);
      await _menuMusic.setVolume(_Settings.volume * 0.5);
      await _menuMusic.play(AssetSource('audio/menu_music.wav'));
    } catch (_) {}
  }

  Future<void> _stopMenuMusic() async {
    try {
      await _menuMusic.stop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/menu_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 80),
              _menuButton('START', () async {
                await _stopMenuMusic();
                if (!context.mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SpaceDodgerGame(autoStart: true),
                  ),
                ).then((_) => _startMenuMusic());
              }),
              _menuButton('SETTINGS', () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                await _startMenuMusic(); // apply new volume
              }),
              _menuButton('EXIT', () => SystemNavigator.pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 220,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0a4a7c),
            foregroundColor: const Color.fromARGB(255, 234, 226, 63),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 6,
          ),
          onPressed: onTap,
          child: Text(
            text,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

/* =========================================================
   SETTINGS SCREEN
========================================================= */

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double volume = _Settings.volume;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sound Volume',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: volume,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: (v) async {
                setState(() => volume = v);
                await _Settings.saveVolume(v);
              },
            ),
            Text('Current: ${(volume * 100).round()}%'),
            const SizedBox(height: 18),
            Text('High Score: ${_Settings.highScore}'),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   GAME
========================================================= */

class SpaceDodgerGame extends StatefulWidget {
  final bool autoStart;
  const SpaceDodgerGame({super.key, this.autoStart = true});

  @override
  State<SpaceDodgerGame> createState() => _SpaceDodgerGameState();
}

class _SpaceDodgerGameState extends State<SpaceDodgerGame>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final Random _rng = Random();
  final List<_Asteroid> _asteroids = [];

  final AudioPlayer _bgMusic = AudioPlayer();

  _GameState state = _GameState.playing;

  double _w = 0, _h = 0;

  Offset _player = const Offset(0.5, 0.82);
  double _targetX = 0.5;
  double _tilt = 0;
  final double _playerRadiusPx = 22;

  // Difficulty: starts slow, increases every 8 sec ✅
  double _spawnTimer = 0;
  double _spawnEvery = 1.10; // slow spawn at start
  double _difficultyTimer = 0;
  double _baseSpeed = 0.40; // slow speed at start

  // FX
  double _shakeTime = 0;
  double _shakeIntensity = 0;

  // Score
  int score = 0;
  int _highScore = _Settings.highScore;

  // Stars
  late final List<_Star> _stars;

  /* ================= SOUND ================= */

  // ✅ FIX: fresh AudioPlayer per SFX (avoids Android -38 / illegal state)
  Future<void> _playSfx(String file) async {
    final p = AudioPlayer();
    try {
      await p.setVolume(_Settings.volume);
      await p.play(AssetSource('audio/$file'));
      p.onPlayerComplete.listen((_) => p.dispose());
    } catch (_) {
      await p.dispose();
    }
  }

  Future<void> _startMusic() async {
    try {
      await _bgMusic.setReleaseMode(ReleaseMode.loop);
      await _bgMusic.setVolume(_Settings.volume * 0.6);
      await _bgMusic.play(AssetSource('audio/bg_music.wav'));
    } catch (_) {}
  }

  Future<void> _stopMusic() async {
    try {
      await _bgMusic.stop();
    } catch (_) {}
  }

  Future<void> _applyMusicVolume() async {
    try {
      await _bgMusic.setVolume(_Settings.volume * 0.6);
    } catch (_) {}
  }

  /* ================= LIFECYCLE ================= */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _stars = List.generate(90, (_) {
      return _Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        r: 0.6 + _rng.nextDouble() * 1.8,
        speed: 0.08 + _rng.nextDouble() * 0.22,
      );
    });

    _ticker = createTicker((elapsed) {
      final dt = (_last == Duration.zero)
          ? 0.016
          : (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;

      if (state == _GameState.playing) {
        _update(dt.clamp(0.0, 0.05));
      }

      if (_shakeTime > 0) {
        _shakeTime -= dt;
        if (_shakeTime <= 0) _shakeIntensity = 0;
      }

      setState(() {});
    });

    _ticker.start();

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _bgMusic.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive) {
      if (state == _GameState.playing) _pauseGame();
    }
    super.didChangeAppLifecycleState(appState);
  }

  /* ================= GAME FLOW ================= */

  Future<void> _startGame() async {
    await _startMusic();

    _asteroids.clear();
    score = 0;

    _spawnTimer = 0;
    _spawnEvery = 1.10;
    _baseSpeed = 0.40;
    _difficultyTimer = 0;

    _player = const Offset(0.5, 0.82);
    _targetX = 0.5;
    _tilt = 0;

    state = _GameState.playing;
  }

  void _pauseGame() async {
    state = _GameState.paused;
    await _stopMusic();
  }

  void _resumeGame() async {
    state = _GameState.playing;
    await _startMusic();
  }

  Future<void> _gameOver() async {
    await _playSfx('hit.wav');
    await _stopMusic();

    if (score > _highScore) {
      _highScore = score;
      await _Settings.saveHighScore(_highScore);
    }

    _shakeTime = 0.25;
    _shakeIntensity = 14;

    state = _GameState.gameOver;
  }

  /* ================= UPDATE ================= */

  void _update(double dt) {
    // Stars
    for (final s in _stars) {
      s.y += s.speed * dt;
      if (s.y > 1.05) {
        s.y = -0.05;
        s.x = _rng.nextDouble();
      }
    }

    // Player smooth follow
    final newX = _player.dx + (_targetX - _player.dx) * 10 * dt;
    _player = Offset(newX.clamp(0.08, 0.92), _player.dy);
    _tilt = (_targetX - _player.dx).clamp(-0.18, 0.18);

    // Difficulty scaling every 8 sec ✅
    _difficultyTimer += dt;
    if (_difficultyTimer >= 8.0) {
      _difficultyTimer = 0;

      _baseSpeed += 0.08; // speed up slowly
      _spawnEvery = max(0.30, _spawnEvery * 0.92); // spawn a bit faster
      _applyMusicVolume();
    }

    // Spawn
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnEvery) {
      _spawnTimer = 0;
      _spawnAsteroid();
    }

    // Move asteroids
    for (final a in _asteroids) {
      a.y += a.speed * dt;
      a.x += a.drift * dt;

      if (a.x < -0.1) a.x = 1.1;
      if (a.x > 1.1) a.x = -0.1;
    }

    // Remove & score
    _asteroids.removeWhere((a) {
      if (a.y > 1.2) {
        score++;
        return true;
      }
      return false;
    });

    // Collision
    final p = Offset(_player.dx * _w, _player.dy * _h);
    for (final a in _asteroids) {
      final c = Offset(a.x * _w, a.y * _h);
      if ((p - c).distance <= (_playerRadiusPx + a.rPx)) {
        _gameOver();
        break;
      }
    }
  }

  void _spawnAsteroid() {
    final rPx = 14 + _rng.nextDouble() * 14;
    _asteroids.add(
      _Asteroid(
        x: _rng.nextDouble().clamp(0.05, 0.95),
        y: -0.2,
        rPx: rPx,
        speed: _baseSpeed + _rng.nextDouble() * 0.45,
        drift: (_rng.nextDouble() - 0.5) * 0.18,
      ),
    );
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          _w = c.maxWidth;
          _h = c.maxHeight;

          final shake = _shakeTime > 0
              ? Offset(
                  (_rng.nextDouble() - 0.5) * _shakeIntensity,
                  (_rng.nextDouble() - 0.5) * _shakeIntensity,
                )
              : Offset.zero;

          return Transform.translate(
            offset: shake,
            child: GestureDetector(
              onPanUpdate: (d) {
                if (state != _GameState.playing) return;
                _targetX = (d.localPosition.dx / _w).clamp(0.05, 0.95);
              },
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _GamePainter(stars: _stars, asteroids: _asteroids),
                    child: const SizedBox.expand(),
                  ),

                  Positioned(
                    left: (_player.dx * _w) - 40,
                    top: (_player.dy * _h) - 40,
                    child: Transform.rotate(
                      angle: _tilt,
                      child: Image.asset(
                        'assets/images/player.png',
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _hudChip('Score: $score'),
                          const SizedBox(width: 8),
                          _hudChip('High: $_highScore'),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Pause',
                            onPressed: () {
                              if (state == _GameState.playing) _pauseGame();
                            },
                            icon: const Icon(Icons.pause_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (state == _GameState.paused)
                    _overlayCard(
                      title: 'PAUSED',
                      subtitle: 'Tap Resume to continue',
                      primaryText: 'Resume',
                      onPrimary: _resumeGame,
                      secondaryText: 'Restart',
                      onSecondary: _startGame,
                    ),
                  if (state == _GameState.gameOver)
                    _overlayCard(
                      title: 'GAME OVER',
                      subtitle: 'Score: $score  •  High: $_highScore',
                      primaryText: 'Play Again',
                      onPrimary: _startGame,
                      secondaryText: 'Back to Menu',
                      onSecondary: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hudChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _overlayCard({
    required String title,
    required String subtitle,
    required String primaryText,
    required VoidCallback onPrimary,
    String? secondaryText,
    VoidCallback? onSecondary,
  }) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.60),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryText),
                ),
              ),
              if (secondaryText != null && onSecondary != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryText),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================================================
   MODELS & PAINTER
========================================================= */

enum _GameState { playing, paused, gameOver }

class _Asteroid {
  _Asteroid({
    required this.x,
    required this.y,
    required this.rPx,
    required this.speed,
    required this.drift,
  });

  double x;
  double y;
  double rPx;
  double speed;
  double drift;
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.speed,
  });

  double x;
  double y;
  double r;
  double speed;
}

class _GamePainter extends CustomPainter {
  final List<_Star> stars;
  final List<_Asteroid> asteroids;

  _GamePainter({required this.stars, required this.asteroids});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050914), Colors.black],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, bg);

    final starPaint = Paint()..color = Colors.white.withOpacity(0.25);
    for (final s in stars) {
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        starPaint,
      );
    }

    final aPaint = Paint()..color = Colors.white.withOpacity(0.25);
    for (final a in asteroids) {
      canvas.drawCircle(
        Offset(a.x * size.width, a.y * size.height),
        a.rPx,
        aPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
