import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/accuracy_notice.dart';

enum _LevelMode { flach, aufrecht }

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  static const _prefsKeyOffsetX = 'level_offset_x';
  static const _prefsKeyOffsetY = 'level_offset_y';

  StreamSubscription<AccelerometerEvent>? _sub;
  AccelerometerEvent? _event;
  bool _unavailable = false;
  _LevelMode _mode = _LevelMode.flach;
  double _offsetX = 0;
  double _offsetY = 0;

  @override
  void initState() {
    super.initState();
    _loadOffsets();
    try {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        (event) {
          if (mounted) setState(() => _event = event);
        },
        onError: (_) {
          if (mounted) setState(() => _unavailable = true);
        },
        cancelOnError: true,
      );
    } catch (_) {
      _unavailable = true;
    }
  }

  Future<void> _loadOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _offsetX = prefs.getDouble(_prefsKeyOffsetX) ?? 0;
      _offsetY = prefs.getDouble(_prefsKeyOffsetY) ?? 0;
    });
  }

  Future<void> _setZeroPoint(double rawX, double rawY) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyOffsetX, rawX);
    await prefs.setDouble(_prefsKeyOffsetY, rawY);
    if (!mounted) return;
    setState(() {
      _offsetX = rawX;
      _offsetY = rawY;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nullpunkt gespeichert.')),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasserwaage'),
        actions: [
          IconButton(
            tooltip: 'Modus wechseln (flach oder aufrecht)',
            icon: Icon(
              _mode == _LevelMode.flach ? Icons.stay_current_landscape : Icons.stay_current_portrait,
            ),
            onPressed: () => setState(() {
              _mode = _mode == _LevelMode.flach ? _LevelMode.aufrecht : _LevelMode.flach;
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: _unavailable
            ? const SensorUnavailableNotice(toolName: 'Die Wasserwaage')
            : _event == null
                ? const Center(child: CircularProgressIndicator())
                : _buildLevel(context, _event!),
      ),
    );
  }

  Widget _buildLevel(BuildContext context, AccelerometerEvent event) {
    // Roll: Neigung um die Längsachse (relevant, wenn das Gerät aufrecht
    // gehalten wird, klassische Wasserwaage). Pitch: Neigung nach vorn/hinten
    // (relevant, wenn das Gerät flach liegt).
    final rollDeg = math.atan2(event.y, event.z) * 180 / math.pi;
    final pitchDeg = math.atan2(-event.x, math.sqrt(event.y * event.y + event.z * event.z)) * 180 / math.pi;

    final displayAngle = _mode == _LevelMode.aufrecht ? rollDeg - _offsetX : pitchDeg - _offsetY;
    final secondaryAngle = _mode == _LevelMode.aufrecht ? pitchDeg - _offsetY : rollDeg - _offsetX;
    final isLevel = displayAngle.abs() < 0.5;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Semantics(
              label:
                  'Aktueller Neigungswinkel: ${displayAngle.toStringAsFixed(1)} Grad, ${isLevel ? "eben" : "nicht eben"}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: _BubblePainter(
                        angleDeg: displayAngle,
                        isLevel: isLevel,
                        primary: Theme.of(context).colorScheme.primary,
                        good: Colors.green,
                        onSurface: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${displayAngle.toStringAsFixed(1)}°',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLevel ? Colors.green : null,
                        ),
                  ),
                  Text(
                    'Querachse: ${secondaryAngle.toStringAsFixed(1)}°',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _setZeroPoint(rollDeg, pitchDeg),
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Nullpunkt hier setzen'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const AccuracyNotice(
          text:
              'Der eingebaute Sensor ist werkseitig nie perfekt justiert. "Nullpunkt hier setzen" gleicht das für eine bekannt ebene Fläche aus.',
        ),
      ],
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.angleDeg,
    required this.isLevel,
    required this.primary,
    required this.good,
    required this.onSurface,
  });

  final double angleDeg;
  final bool isLevel;
  final Color primary;
  final Color good;
  final Color onSurface;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = onSurface.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 2, ringPaint);
    canvas.drawCircle(center, 6, ringPaint..strokeWidth = 1.5);

    // Blase entlang einer Achse verschieben, begrenzt auf 45 Grad Anschlag.
    final clamped = angleDeg.clamp(-45, 45) / 45;
    final bubbleCenter = Offset(center.dx, center.dy - clamped * (radius - 24));

    final bubblePaint = Paint()..color = (isLevel ? good : primary).withValues(alpha: 0.85);
    canvas.drawCircle(bubbleCenter, 18, bubblePaint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.angleDeg != angleDeg || oldDelegate.isLevel != isLevel;
}
