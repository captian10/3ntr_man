import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double v = AppSettings.volume;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sound Volume',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Slider(
              value: v,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(v * 100).round()}%',
              onChanged: (value) async {
                setState(() => v = value);
                await AppSettings.saveVolume(value);
              },
            ),
            const SizedBox(height: 10),
            Text('Current: ${(v * 100).round()}%'),
          ],
        ),
      ),
    );
  }
}
