import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';

import '../widgets/accuracy_notice.dart';

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  StreamSubscription<CompassEvent>? _sub;
  CompassEvent? _event;
  bool _unavailable = false;
  Timer? _availabilityTimer;

  @override
  void initState() {
    super.initState();
    final events = FlutterCompass.events;
    if (events == null) {
      _unavailable = true;
      return;
    }
    // Manche Geraete liefern den Stream, aber nie ein Ereignis, wenn der
    // Sensor fehlt. Deshalb: kurze Wartezeit, danach als nicht verfuegbar
    // einstufen, statt eine leere Anzeige endlos zu zeigen.
    _availabilityTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _event == null) {
        setState(() => _unavailable = true);
      }
    });
    _sub = events.listen((event) {
      _availabilityTimer?.cancel();
      if (mounted) setState(() => _event = event);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _availabilityTimer?.cancel();
    super.dispose();
  }

  String _cardinal(double heading) {
    const dirs = [
      'Norden', 'Nordnordost', 'Nordost', 'Ostnordost',
      'Osten', 'Ostsuedost', 'Suedost', 'Suedsuedost',
      'Sueden', 'Suedsuedwest', 'Suedwest', 'Westsuedwest',
      'Westen', 'Westnordwest', 'Nordwest', 'Nordnordwest',
    ];
    final index = ((heading % 360) / 22.5).round() % 16;
    return dirs[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kompass')),
      body: SafeArea(
        child: _unavailable
            ? const SensorUnavailableNotice(toolName: 'Der Kompass')
            : _event == null
                ? const Center(child: CircularProgressIndicator())
                : _buildCompass(context, _event!),
      ),
    );
  }

  Widget _buildCompass(BuildContext context, CompassEvent event) {
    final heading = event.heading ?? 0;
    final accuracy = event.accuracy;
    final lowAccuracy = accuracy == null || accuracy > 15;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Semantics(
              label:
                  'Aktuelle Ausrichtung: ${heading.round()} Grad, ${_cardinal(heading)}',
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -heading * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(260, 260),
                        painter: _CompassPainter(
                          color: Theme.of(context).colorScheme.primary,
                          onSurface: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${heading.round()}°',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _cardinal(heading),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (lowAccuracy)
          const AccuracyNotice(
            text:
                'Geringe Genauigkeit erkannt. Bewege das Geraet einmal in einer liegenden Acht, um den Kompass neu zu kalibrieren.',
          )
        else
          AccuracyNotice(
            text:
                'Geschaetzte Abweichung: ±${accuracy.round()} Grad. Kompasse reagieren empfindlich auf Metall und Magnete in der Naehe.',
          ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.color, required this.onSurface});

  final Color color;
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

    final needlePaint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius + 10)
      ..lineTo(center.dx - 12, center.dy)
      ..lineTo(center.dx, center.dy + radius - 10)
      ..lineTo(center.dx + 12, center.dy)
      ..close();
    canvas.drawPath(path, needlePaint);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: 'N',
      style: TextStyle(color: onSurface, fontWeight: FontWeight.bold, fontSize: 16),
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - radius + 14));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) => false;
}
