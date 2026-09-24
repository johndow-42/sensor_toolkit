import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/accuracy_notice.dart';

enum _LevelMode { flach, aufrecht }

/// Wasserwaage. Zwei formal unterschiedliche Libellen statt einer einzigen
/// Kreisgrafik fuer beide Modi (siehe design/redesign-*.md, Abschnitt 2.3):
/// flach = runde Dosenlibelle (zwei Achsen), aufrecht = laengliche
/// Roehrenlibelle (eine Achse, zweite Achse als kleine Nebenanzeige).
class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  static const _prefsKeyOffsetX = 'level_offset_x';
  static const _prefsKeyOffsetY = 'level_offset_y';
  static const _prefsKeyCalibrated = 'level_calibrated';
  // Engerer Ausschlagbereich statt der frueheren 45 Grad: im alltagsrelevanten
  // Bereich (1-5 Grad Abweichung) macht das die Blase erst richtig ablesbar.
  static const double _maxTiltDeg = 10;

  StreamSubscription<AccelerometerEvent>? _sub;
  AccelerometerEvent? _event;
  bool _unavailable = false;
  _LevelMode _mode = _LevelMode.flach;
  double _offsetX = 0;
  double _offsetY = 0;
  bool _calibrated = false;

  @override
  void initState() {
    super.initState();
    _loadOffsets();
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen(
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
    final x = prefs.getDouble(_prefsKeyOffsetX) ?? 0;
    final y = prefs.getDouble(_prefsKeyOffsetY) ?? 0;
    // Migration: aeltere Installationen kennen noch kein _prefsKeyCalibrated,
    // dort aus einem vorhandenen Offset ungleich Null auf "kalibriert" schliessen.
    final storedCalibrated = prefs.getBool(_prefsKeyCalibrated);
    setState(() {
      _offsetX = x;
      _offsetY = y;
      _calibrated = storedCalibrated ?? (x != 0 || y != 0);
    });
  }

  Future<void> _setZeroPoint(double rawX, double rawY) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyOffsetX, rawX);
    await prefs.setDouble(_prefsKeyOffsetY, rawY);
    await prefs.setBool(_prefsKeyCalibrated, true);
    if (!mounted) return;
    setState(() {
      _offsetX = rawX;
      _offsetY = rawY;
      _calibrated = true;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Nullpunkt gespeichert.')));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wasserwaage')),
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
    // Roll: Neigung um die Laengsachse (relevant im aufrecht-Modus, klassische
    // Wasserwaage an einer Wand). Pitch: Neigung nach vorn/hinten (relevant,
    // wenn das Geraet flach liegt).
    final rollDeg = math.atan2(event.y, event.z) * 180 / math.pi;
    final pitchDeg =
        math.atan2(-event.x, math.sqrt(event.y * event.y + event.z * event.z)) *
        180 /
        math.pi;

    final displayAngle = _mode == _LevelMode.aufrecht
        ? rollDeg - _offsetX
        : pitchDeg - _offsetY;
    final secondaryAngle = _mode == _LevelMode.aufrecht
        ? pitchDeg - _offsetY
        : rollDeg - _offsetX;
    final isLevel =
        displayAngle.abs() < 0.5 &&
        (_mode == _LevelMode.aufrecht || secondaryAngle.abs() < 0.5);

    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<_LevelMode>(
            segments: const [
              ButtonSegment(
                value: _LevelMode.flach,
                label: Text('Flach'),
                icon: Icon(Icons.stay_current_landscape),
              ),
              ButtonSegment(
                value: _LevelMode.aufrecht,
                label: Text('Aufrecht'),
                icon: Icon(Icons.stay_current_portrait),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // SingleChildScrollView statt bloßem Center: die Röhrenlibelle
              // im aufrecht-Modus ist zusammen mit Zahl/Knopf/Status-Zeile auf
              // kleineren Bildschirmen höher als der verfügbare Platz - ein
              // reiner Center-Layout würde dann hart überlaufen (live auf dem
              // Emulator beobachtet), statt nur bei Bedarf zu scrollen.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Semantics(
                      label:
                          'Aktueller Neigungswinkel: ${displayAngle.toStringAsFixed(1)} Grad, '
                          '${isLevel ? "eben" : "nicht eben"}',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_mode == _LevelMode.flach)
                            _CircularBubbleLevel(
                              xDeg: secondaryAngle,
                              yDeg: displayAngle,
                              maxTiltDeg: _maxTiltDeg,
                              isLevel: isLevel,
                              scheme: scheme,
                            )
                          else
                            _TubeBubbleLevel(
                              angleDeg: displayAngle,
                              secondaryAngleDeg: secondaryAngle,
                              maxTiltDeg: _maxTiltDeg,
                              isLevel: isLevel,
                              scheme: scheme,
                            ),
                          const SizedBox(height: 20),
                          Text(
                            '${displayAngle.toStringAsFixed(1)}°',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
                          const SizedBox(height: 6),
                          Text(
                            _calibrated
                                ? 'Eigene Kalibrierung aktiv'
                                : 'Werksnullpunkt (nicht angepasst)',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const AccuracyNotice(
          text:
              'Der eingebaute Sensor ist werkseitig nie perfekt justiert. '
              '"Nullpunkt hier setzen" gleicht das für eine bekannt ebene Fläche aus.',
        ),
      ],
    );
  }
}

/// Runde Dosenlibelle fuer den flach-Modus: Blase wandert auf beiden Achsen.
class _CircularBubbleLevel extends StatelessWidget {
  const _CircularBubbleLevel({
    required this.xDeg,
    required this.yDeg,
    required this.maxTiltDeg,
    required this.isLevel,
    required this.scheme,
  });

  final double xDeg;
  final double yDeg;
  final double maxTiltDeg;
  final bool isLevel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: CustomPaint(
        painter: _CircularLevelPainter(
          xDeg: xDeg,
          yDeg: yDeg,
          maxTiltDeg: maxTiltDeg,
          isLevel: isLevel,
          primary: scheme.primary,
          good: Colors.green,
          onSurface: scheme.onSurface,
          surfaceContainerHighest: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class _CircularLevelPainter extends CustomPainter {
  _CircularLevelPainter({
    required this.xDeg,
    required this.yDeg,
    required this.maxTiltDeg,
    required this.isLevel,
    required this.primary,
    required this.good,
    required this.onSurface,
    required this.surfaceContainerHighest,
  });

  final double xDeg;
  final double yDeg;
  final double maxTiltDeg;
  final bool isLevel;
  final Color primary;
  final Color good;
  final Color onSurface;
  final Color surfaceContainerHighest;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final usableRadius = radius - 30;

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()..color = surfaceContainerHighest,
    );

    // Konzentrische Toleranzringe statt eines einzelnen Rings, damit der
    // Blasenabstand vom Zentrum eine ablesbare Bedeutung hat.
    final ringPaint = Paint()
      ..color = onSurface.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final t in [maxTiltDeg / 3, maxTiltDeg * 2 / 3, maxTiltDeg]) {
      canvas.drawCircle(center, (t / maxTiltDeg) * usableRadius, ringPaint);
    }
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = onSurface.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = onSurface.withValues(alpha: 0.4),
    );

    final clampedX = xDeg.clamp(-maxTiltDeg, maxTiltDeg) / maxTiltDeg;
    final clampedY = yDeg.clamp(-maxTiltDeg, maxTiltDeg) / maxTiltDeg;
    final bubbleCenter = Offset(
      center.dx + clampedX * usableRadius,
      center.dy - clampedY * usableRadius,
    );

    final bubbleColor = isLevel ? good : primary;
    canvas.drawCircle(
      bubbleCenter,
      16,
      Paint()..color = bubbleColor.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      bubbleCenter,
      16,
      Paint()
        ..color = bubbleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularLevelPainter oldDelegate) =>
      oldDelegate.xDeg != xDeg ||
      oldDelegate.yDeg != yDeg ||
      oldDelegate.isLevel != isLevel;
}

/// Laengliche Roehrenlibelle fuer den aufrecht-Modus, plus kleine
/// Nebenanzeige fuer die jeweils andere Achse.
class _TubeBubbleLevel extends StatelessWidget {
  const _TubeBubbleLevel({
    required this.angleDeg,
    required this.secondaryAngleDeg,
    required this.maxTiltDeg,
    required this.isLevel,
    required this.scheme,
  });

  final double angleDeg;
  final double secondaryAngleDeg;
  final double maxTiltDeg;
  final bool isLevel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 300,
            child: CustomPaint(
              painter: _TubeLevelPainter(
                angleDeg: angleDeg,
                maxTiltDeg: maxTiltDeg,
                isLevel: isLevel,
                primary: scheme.primary,
                good: Colors.green,
                onSurface: scheme.onSurface,
                surfaceContainerHighest: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Opacity(
              opacity: 0.8,
              child: SizedBox(
                width: 52,
                height: 52,
                child: CustomPaint(
                  painter: _MiniLevelPainter(
                    deg: secondaryAngleDeg,
                    maxTiltDeg: maxTiltDeg,
                    primary: scheme.primary,
                    onSurface: scheme.onSurface,
                    surfaceContainerHighest: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TubeLevelPainter extends CustomPainter {
  _TubeLevelPainter({
    required this.angleDeg,
    required this.maxTiltDeg,
    required this.isLevel,
    required this.primary,
    required this.good,
    required this.onSurface,
    required this.surfaceContainerHighest,
  });

  final double angleDeg;
  final double maxTiltDeg;
  final bool isLevel;
  final Color primary;
  final Color good;
  final Color onSurface;
  final Color surfaceContainerHighest;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = surfaceContainerHighest);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = onSurface.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final centerY = size.height / 2;
    final usableHalf = size.height / 2 - 24;

    // Referenzlinien: die Blase muss dazwischen stehen, damit "eben" gilt.
    final refPaint = Paint()
      ..color = primary
      ..strokeWidth = 2;
    final toleranceHalfHeight = (0.5 / maxTiltDeg) * usableHalf;
    canvas.drawLine(
      Offset(10, centerY - toleranceHalfHeight),
      Offset(size.width - 10, centerY - toleranceHalfHeight),
      refPaint,
    );
    canvas.drawLine(
      Offset(10, centerY + toleranceHalfHeight),
      Offset(size.width - 10, centerY + toleranceHalfHeight),
      refPaint,
    );

    // Gradmarken links/rechts.
    final tickPaint = Paint()
      ..color = onSurface.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (double d = -maxTiltDeg; d <= maxTiltDeg; d += 2) {
      final y = centerY - (d / maxTiltDeg) * usableHalf;
      final isMajor = d.round() % 4 == 0;
      final len = isMajor ? 10.0 : 6.0;
      canvas.drawLine(Offset(0, y), Offset(len, y), tickPaint);
      canvas.drawLine(
        Offset(size.width, y),
        Offset(size.width - len, y),
        tickPaint,
      );
    }

    final clamped = angleDeg.clamp(-maxTiltDeg, maxTiltDeg) / maxTiltDeg;
    final bubbleY = centerY - clamped * usableHalf;
    final bubbleColor = isLevel ? good : primary;
    canvas.drawCircle(
      Offset(size.width / 2, bubbleY),
      size.width / 2 - 10,
      Paint()..color = bubbleColor.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _TubeLevelPainter oldDelegate) =>
      oldDelegate.angleDeg != angleDeg || oldDelegate.isLevel != isLevel;
}

/// Kleine Nebenanzeige fuer die im Roehren-Modus nicht primaer dargestellte
/// Achse - selbes visuelles Vokabular wie die Dosenlibelle, nur einachsig.
class _MiniLevelPainter extends CustomPainter {
  _MiniLevelPainter({
    required this.deg,
    required this.maxTiltDeg,
    required this.primary,
    required this.onSurface,
    required this.surfaceContainerHighest,
  });

  final double deg;
  final double maxTiltDeg;
  final Color primary;
  final Color onSurface;
  final Color surfaceContainerHighest;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()..color = surfaceContainerHighest,
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = onSurface.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final clamped = deg.clamp(-maxTiltDeg, maxTiltDeg) / maxTiltDeg;
    final bubbleCenter = Offset(center.dx, center.dy - clamped * (radius - 10));
    canvas.drawCircle(
      bubbleCenter,
      6,
      Paint()..color = primary.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniLevelPainter oldDelegate) =>
      oldDelegate.deg != deg;
}
