import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/accuracy_notice.dart';

enum _HoldState { live, holding, frozen }

/// Kompass. Statt einer rotierenden Nadel jetzt ein rotierendes Zifferblatt
/// mit fixem Zeiger oben (Stil professioneller Kompass-Apps), dazu eine
/// Winkel-Halten-Funktion (Knopf druecken+halten, drehen, loslassen misst
/// den ueberstrichenen Winkel) und eine einfache Zielmarkierung.
/// Siehe design/redesign-kompass-lineal-wasserwaage.md, Abschnitte 2.1 & 3.
class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  static const _prefsKeyTarget = 'compass_target_heading';

  StreamSubscription<CompassEvent>? _sub;
  CompassEvent? _event;
  bool _unavailable = false;
  Timer? _availabilityTimer;

  _HoldState _holdState = _HoldState.live;
  double? _referenceHeading;
  double _liveDelta = 0;
  double _frozenDelta = 0;
  double _frozenFrom = 0;
  double _frozenTo = 0;
  double? _targetHeading;

  @override
  void initState() {
    super.initState();
    _loadTarget();
    final events = FlutterCompass.events;
    if (events == null) {
      _unavailable = true;
      return;
    }
    // Manche Geräte liefern den Stream, aber nie ein Ereignis, wenn der
    // Sensor fehlt. Deshalb: kurze Wartezeit, danach als nicht verfügbar
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

  Future<void> _loadTarget() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _targetHeading = prefs.getDouble(_prefsKeyTarget));
  }

  Future<void> _toggleTarget(double currentHeading) async {
    final prefs = await SharedPreferences.getInstance();
    if (_targetHeading == null) {
      await prefs.setDouble(_prefsKeyTarget, currentHeading);
      if (!mounted) return;
      setState(() => _targetHeading = currentHeading);
    } else {
      await prefs.remove(_prefsKeyTarget);
      if (!mounted) return;
      setState(() => _targetHeading = null);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _availabilityTimer?.cancel();
    super.dispose();
  }

  String _cardinal(double heading) {
    const dirs = [
      'Norden',
      'Nordnordost',
      'Nordost',
      'Ostnordost',
      'Osten',
      'Ostsüdost',
      'Südost',
      'Südsüdost',
      'Süden',
      'Südsüdwest',
      'Südwest',
      'Westsüdwest',
      'Westen',
      'Westnordwest',
      'Nordwest',
      'Nordnordwest',
    ];
    final index = ((heading % 360) / 22.5).round() % 16;
    return dirs[index];
  }

  double _normalizeDelta(double delta) =>
      ((delta + 180) % 360 + 360) % 360 - 180;

  void _startHold(double currentHeading) {
    setState(() {
      _holdState = _HoldState.holding;
      _referenceHeading = currentHeading;
      _liveDelta = 0;
    });
  }

  void _updateHold(double currentHeading) {
    final reference = _referenceHeading;
    if (reference == null) return;
    // Kein setState hier - build() laeuft ohnehin bei jedem Sensor-Event neu
    // (siehe Listener in initState), _liveDelta wird direkt fuer die Anzeige
    // in derselben build()-Passage aktualisiert (siehe _buildCompass).
    _liveDelta = _normalizeDelta(currentHeading - reference);
  }

  void _endHold(double currentHeading) {
    final reference = _referenceHeading;
    if (reference == null) return;
    setState(() {
      _frozenFrom = reference;
      _frozenTo = currentHeading;
      _frozenDelta = _liveDelta;
      _holdState = _HoldState.frozen;
      _referenceHeading = null;
    });
  }

  void _cancelHold() {
    setState(() {
      _holdState = _HoldState.live;
      _referenceHeading = null;
    });
  }

  void _resetToLive() {
    setState(() {
      _holdState = _HoldState.live;
      _referenceHeading = null;
    });
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(
      ClipboardData(text: '${_frozenDelta.abs().round()}°'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Wert kopiert.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kompass'),
        actions: [
          if (_event != null && !_unavailable)
            IconButton(
              tooltip: _targetHeading == null
                  ? 'Ziel markieren'
                  : 'Ziel entfernen',
              icon: Icon(
                _targetHeading == null
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
              ),
              onPressed: () => _toggleTarget(_event!.heading ?? 0),
            ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;

    if (_holdState == _HoldState.holding) {
      _updateHold(heading);
    }

    final bool isHolding = _holdState == _HoldState.holding;
    final bool isFrozen = _holdState == _HoldState.frozen;
    final double shownValue = isFrozen
        ? _frozenDelta
        : (isHolding ? _liveDelta : heading);
    final String bigLabel = isHolding || isFrozen
        ? '${shownValue >= 0 ? "+" : "-"}${shownValue.abs().round()}°'
        : '${heading.round()}°';

    double? targetDelta;
    if (_targetHeading != null && _holdState == _HoldState.live) {
      targetDelta = _normalizeDelta(_targetHeading! - heading);
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Semantics(
              label: isHolding || isFrozen
                  ? 'Gehaltener Winkel: ${shownValue.abs().round()} Grad'
                  : 'Aktuelle Ausrichtung: ${heading.round()} Grad, ${_cardinal(heading)}',
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -heading * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(280, 280),
                        painter: _CompassPainter(
                          primary: scheme.primary,
                          onSurface: scheme.onSurface,
                          onSurfaceVariant: scheme.onSurfaceVariant,
                          surfaceContainerHighest:
                              scheme.surfaceContainerHighest,
                          dimmed: lowAccuracy || isFrozen,
                          currentHeading: heading,
                          referenceHeading: isHolding
                              ? _referenceHeading
                              : null,
                          targetHeading: _targetHeading,
                          mainLabelStyle: Theme.of(context)
                              .textTheme
                              .titleMedium,
                          subLabelStyle: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    const Positioned(top: 2, child: _FixedPointer()),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bigLabel,
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        if (!isHolding && !isFrozen)
                          Text(
                            _cardinal(heading),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        if (isFrozen)
                          Text(
                            'Winkel gehalten',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        if (targetDelta != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Ziel: ${_targetHeading!.round()}° (Δ ${targetDelta.abs().round()}°)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isFrozen) _buildFrozenCard(context),
        if (!isFrozen) ...[
          _HoldButton(
            holding: isHolding,
            onPressStart: () => _startHold(heading),
            onPressEnd: () => _endHold(heading),
            onPressCancel: _cancelHold,
          ),
          const SizedBox(height: 12),
        ],
        if (_holdState == _HoldState.live)
          if (lowAccuracy)
            const AccuracyNotice(
              text:
                  'Geringe Genauigkeit erkannt. Bewege das Gerät einmal in einer liegenden Acht, '
                  'um den Kompass neu zu kalibrieren.',
            )
          else
            AccuracyNotice(
              text:
                  'Geschätzte Abweichung: ±${accuracy.round()} Grad. Kompasse reagieren empfindlich '
                  'auf Metall und Magnete in der Nähe.',
            )
        else
          const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFrozenCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'zwischen ${_frozenFrom.round()}° und ${_frozenTo.round()}°',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetToLive,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Neu messen'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _copyResult,
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopieren'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Press-and-hold-Knopf fuer die Winkel-Halten-Funktion. Bewusst ueber
/// onTapDown/onTapUp statt onLongPress* implementiert, damit das Halten
/// ohne die eingebaute Verzoegerung von Flutters Long-Press-Geste sofort
/// beim Aufsetzen des Fingers beginnt.
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.holding,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onPressCancel,
  });

  final bool holding;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onPressCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: holding
          ? 'Winkel wird gemessen, loslassen zum Beenden'
          : 'Winkel festhalten, gedrückt halten und drehen',
      child: GestureDetector(
        onTapDown: (_) => onPressStart(),
        onTapUp: (_) => onPressEnd(),
        onTapCancel: onPressCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: holding ? scheme.primaryContainer : null,
            border: Border.all(
              color: holding ? scheme.primary : scheme.outline,
              width: holding ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                holding ? Icons.lock : Icons.lock_outline,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                holding ? 'Halten … loslassen zum Messen' : 'Winkel festhalten',
                style: TextStyle(color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FixedPointer extends StatelessWidget {
  const _FixedPointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 14),
      painter: _FixedPointerPainter(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _FixedPointerPainter extends CustomPainter {
  _FixedPointerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FixedPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.primary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surfaceContainerHighest,
    required this.dimmed,
    required this.currentHeading,
    this.referenceHeading,
    this.targetHeading,
    this.mainLabelStyle,
    this.subLabelStyle,
  });

  final Color primary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color surfaceContainerHighest;
  final bool dimmed;
  final double currentHeading;
  final double? referenceHeading;
  final double? targetHeading;
  final TextStyle? mainLabelStyle;
  final TextStyle? subLabelStyle;

  // int-Schlüssel statt double: Dart erlaubt double nicht als const-Map-Key
  // (Gleichheits-/Hash-Semantik). In _pointAt() wird ohnehin nach double
  // konvertiert.
  static const _mainDirs = {0: 'N', 90: 'O', 180: 'S', 270: 'W'};
  static const _subDirs = {45: 'NO', 135: 'SO', 225: 'SW', 315: 'NW'};

  Offset _pointAt(Offset center, double radius, double bearingDeg) {
    final rad = (bearingDeg - 90) * math.pi / 180;
    return Offset(
      center.dx + radius * math.cos(rad),
      center.dy + radius * math.sin(rad),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final dimFactor = dimmed ? 0.4 : 1.0;

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()..color = surfaceContainerHighest.withValues(alpha: dimFactor),
    );
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = onSurface.withValues(alpha: 0.2 * dimFactor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Sektorflaeche + gestrichelter Geisterzeiger waehrend des Haltens:
    // macht den gemessenen Winkel als Flaeche sichtbar, nicht nur als Zahl.
    final reference = referenceHeading;
    if (reference != null) {
      final startRad = (reference - 90) * math.pi / 180;
      final sweepDeg =
          ((currentHeading - reference + 180) % 360 + 360) % 360 - 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 10),
        startRad,
        sweepDeg * math.pi / 180,
        true,
        Paint()..color = primary.withValues(alpha: 0.18),
      );
      _drawDashedLine(
        canvas,
        center,
        _pointAt(center, radius - 10, reference),
        onSurface.withValues(alpha: 0.6),
      );
    }

    // Tick-Marken alle 5 Grad.
    for (int deg = 0; deg < 360; deg += 5) {
      final isMajor = deg % 30 == 0;
      final isMid = deg % 15 == 0;
      final outer = _pointAt(center, radius - 4, deg.toDouble());
      final len = isMajor ? 16.0 : (isMid ? 11.0 : 6.0);
      final inner = _pointAt(center, radius - 4 - len, deg.toDouble());
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = onSurfaceVariant.withValues(
            alpha: (isMajor ? 0.8 : 0.4) * dimFactor,
          )
          ..strokeWidth = isMajor ? 2 : 1,
      );
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    final mainStyle =
        mainLabelStyle ??
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 18);
    final subStyle = subLabelStyle ?? const TextStyle(fontSize: 11);

    _mainDirs.forEach((deg, label) {
      final isNorth = deg == 0;
      final pos = _pointAt(center, radius - 34, deg.toDouble());
      tp.text = TextSpan(
        text: label,
        style: mainStyle.copyWith(
          color: (isNorth ? primary : onSurface).withValues(alpha: dimFactor),
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    _subDirs.forEach((deg, label) {
      final pos = _pointAt(center, radius - 28, deg.toDouble());
      tp.text = TextSpan(
        text: label,
        style: subStyle.copyWith(
          color: onSurfaceVariant.withValues(alpha: dimFactor),
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    // Zielmarkierung: kleiner, dauerhafter Stecknadel-Punkt an der
    // gespeicherten Peilung, unabhaengig vom Halten-Zustand.
    final target = targetHeading;
    if (target != null) {
      final pos = _pointAt(center, radius - 16, target);
      canvas.drawCircle(
        pos,
        6,
        Paint()..color = Colors.orange.withValues(alpha: dimFactor),
      );
      canvas.drawCircle(
        pos,
        6,
        Paint()
          ..color = Colors.orange.shade900.withValues(alpha: dimFactor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Color color) {
    const dashLength = 6.0;
    const gapLength = 4.0;
    final total = (to - from).distance;
    if (total == 0) return;
    final direction = (to - from) / total;
    var covered = 0.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    while (covered < total) {
      final segStart = from + direction * covered;
      final segEnd = from + direction * math.min(covered + dashLength, total);
      canvas.drawLine(segStart, segEnd, paint);
      covered += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.currentHeading != currentHeading ||
      oldDelegate.referenceHeading != referenceHeading ||
      oldDelegate.targetHeading != targetHeading ||
      oldDelegate.dimmed != dimmed;
}
