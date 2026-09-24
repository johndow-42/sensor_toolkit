import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/accuracy_notice.dart';

enum _Unit { mm, zoll }

enum _ReferenceObject { kreditkarte, a4 }

/// Bildschirm-Lineal. Flutters devicePixelRatio allein ergibt keine
/// verlässliche physische Größe (siehe concept.md), deshalb Kalibrierung
/// gegen ein bekanntes Referenzobjekt, Ergebnis lokal gespeichert.
///
/// Zwei vorher gemeldete Bugs behoben (siehe design/redesign-*.md):
/// 1) Die Einheit war nirgends sichtbar (nur nackte Zahlen) - jetzt per
///    SegmentedButton und "0 cm"-Beschriftung dauerhaft lesbar.
/// 2) Ohne Kalibrierung landete praktisch jeder dauerhaft bei einer groben
///    Dichte-Schätzung (`_fallbackPxPerMm`) - jetzt eine aktive
///    Kalibrierungs-Aufforderung statt einer stillen Fußnote.
class RulerScreen extends StatefulWidget {
  const RulerScreen({super.key});

  @override
  State<RulerScreen> createState() => _RulerScreenState();
}

class _RulerScreenState extends State<RulerScreen> {
  static const _prefsKey = 'ruler_px_per_mm';

  double? _pxPerMm;
  bool _calibrating = false;
  double _calibrationWidthPx = 300;
  _Unit _unit = _Unit.mm;
  _ReferenceObject _referenceObject = _ReferenceObject.kreditkarte;
  bool _schieblehreActive = false;
  double? _leftMarkerX;
  double? _rightMarkerX;

  double get _referenceWidthMm =>
      _referenceObject == _ReferenceObject.kreditkarte ? 85.6 : 210.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _pxPerMm = prefs.getDouble(_prefsKey));
  }

  Future<void> _saveCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final pxPerMm = _calibrationWidthPx / _referenceWidthMm;
    await prefs.setDouble(_prefsKey, pxPerMm);
    if (!mounted) return;
    setState(() {
      _pxPerMm = pxPerMm;
      _calibrating = false;
    });
  }

  double _fallbackPxPerMm(BuildContext context) {
    // Grobe Schätzung über die logische Displaydichte, nur als Notlösung
    // vor der ersten Kalibrierung. Nicht verlässlich, siehe Hinweistext.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final assumedDpi = 160 * dpr;
    return assumedDpi / 25.4;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lineal'),
        actions: [
          if (!_calibrating) ...[
            IconButton(
              tooltip: _schieblehreActive
                  ? 'Zurück zum Lineal'
                  : 'Messschieber',
              icon: Icon(
                _schieblehreActive ? Icons.straighten : Icons.compare_arrows,
              ),
              onPressed: () => setState(() {
                _schieblehreActive = !_schieblehreActive;
                _leftMarkerX = null;
                _rightMarkerX = null;
              }),
            ),
            IconButton(
              tooltip: 'Kalibrieren',
              icon: const Icon(Icons.tune),
              onPressed: () => setState(() => _calibrating = true),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _calibrating
            ? _buildCalibration(context)
            : _buildRulerScreen(context),
      ),
    );
  }

  Widget _buildRulerScreen(BuildContext context) {
    final calibrated = _pxPerMm != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<_Unit>(
            segments: const [
              ButtonSegment(
                value: _Unit.mm,
                label: Text('cm'),
                icon: Icon(Icons.straighten),
              ),
              ButtonSegment(value: _Unit.zoll, label: Text('Zoll')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
        ),
        if (!calibrated) _buildCalibrationPromptCard(context),
        Expanded(child: _buildRuler(context)),
        AccuracyNotice(
          text: calibrated
              ? 'Kalibriert gegen ${_referenceObject == _ReferenceObject.kreditkarte ? "eine Scheckkarte" : "ein A4-Blatt"}. '
                    'Gilt nur für diesen Bildschirm, nicht übertragbar auf andere Geräte.'
              : 'Grobe Schätzung ohne Kalibrierung, Abweichung oft über 20 %. Oben "Jetzt kalibrieren" tippen.',
        ),
      ],
    );
  }

  Widget _buildCalibrationPromptCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Noch nicht kalibriert, Maße stimmen wahrscheinlich nicht.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () => setState(() => _calibrating = true),
              child: const Text('Jetzt kalibrieren'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibration(BuildContext context) {
    final pxPerMmLive = _calibrationWidthPx / _referenceWidthMm;
    final isKreditkarte = _referenceObject == _ReferenceObject.kreditkarte;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SegmentedButton<_ReferenceObject>(
            segments: const [
              ButtonSegment(
                value: _ReferenceObject.kreditkarte,
                label: Text('Scheckkarte'),
              ),
              ButtonSegment(
                value: _ReferenceObject.a4,
                label: Text('A4-Blatt'),
              ),
            ],
            selected: {_referenceObject},
            onSelectionChanged: (s) =>
                setState(() => _referenceObject = s.first),
          ),
          const SizedBox(height: 16),
          Text(
            isKreditkarte
                ? 'Halte eine Scheckkarte (85,6 mm breit) an den Bildschirm und ziehe den Regler, bis der Balken genau so breit ist wie die Karte.'
                : 'Halte ein A4-Blatt quer an den Bildschirm (210 mm breite Seite) und ziehe den Regler, bis der Balken genau so breit ist wie das Blatt.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            width: _calibrationWidthPx,
            height: isKreditkarte ? 54 : 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(isKreditkarte ? 8 : 2),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Feinjustierung -1 px',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() {
                  _calibrationWidthPx = (_calibrationWidthPx - 1).clamp(
                    100,
                    MediaQuery.of(context).size.width - 20,
                  );
                }),
              ),
              Text(
                'aktuell: ${pxPerMmLive.toStringAsFixed(2)} px/mm',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                tooltip: 'Feinjustierung +1 px',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() {
                  _calibrationWidthPx = (_calibrationWidthPx + 1).clamp(
                    100,
                    MediaQuery.of(context).size.width - 20,
                  );
                }),
              ),
            ],
          ),
          Slider(
            min: 100,
            max: MediaQuery.of(context).size.width - 20,
            value: _calibrationWidthPx.clamp(
              100,
              MediaQuery.of(context).size.width - 20,
            ),
            onChanged: (v) => setState(() => _calibrationWidthPx = v),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() => _calibrating = false),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saveCalibration,
                child: const Text('Speichern'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuler(BuildContext context) {
    final pxPerMm = _pxPerMm ?? _fallbackPxPerMm(context);
    final color = Theme.of(context).colorScheme.onSurface;
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          _leftMarkerX ??= width * 0.25;
          _rightMarkerX ??= width * 0.75;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RulerPainter(
                    pxPerMm: pxPerMm,
                    unit: _unit,
                    color: color,
                    labelStyle: labelStyle,
                  ),
                ),
              ),
              if (_schieblehreActive)
                Positioned.fill(
                  child: _SchieblehreOverlay(
                    width: width,
                    leftX: _leftMarkerX!,
                    rightX: _rightMarkerX!,
                    pxPerMm: pxPerMm,
                    unit: _unit,
                    color: Theme.of(context).colorScheme.primary,
                    onChanged: (l, r) => setState(() {
                      _leftMarkerX = l;
                      _rightMarkerX = r;
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.pxPerMm,
    required this.unit,
    required this.color,
    this.labelStyle,
  });

  final double pxPerMm;
  final _Unit unit;
  final Color color;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final majorPaint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final minorPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final baseStyle = labelStyle ?? const TextStyle(fontSize: 12);

    if (unit == _Unit.mm) {
      final stepPx = pxPerMm;
      var mm = 0;
      for (double x = 0; x < size.width; x += stepPx, mm++) {
        final isCm = mm % 10 == 0;
        final isHalf = mm % 5 == 0;
        final h = isCm ? 40.0 : (isHalf ? 26.0 : 16.0);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h),
          isCm || isHalf ? majorPaint : minorPaint,
        );
        if (isCm) {
          // Einheit wird nur einmal am Nullpunkt ausgeschrieben (Konvention
          // echter Lineale), danach reichen die nackten Zentimeter-Zahlen -
          // der SegmentedButton oben haelt die aktive Einheit zusaetzlich
          // dauerhaft sichtbar.
          final label = mm == 0 ? '0 cm' : '${mm ~/ 10}';
          tp.text = TextSpan(
            text: label,
            style: baseStyle.copyWith(color: color),
          );
          tp.layout();
          tp.paint(canvas, Offset(x + 2, h + 2));
        }
      }
    } else {
      final pxPerInch = pxPerMm * 25.4;
      final pxPerSixteenth = pxPerInch / 16;
      var i = 0;
      for (double x = 0; x < size.width; x += pxPerSixteenth, i++) {
        final isInch = i % 16 == 0;
        final isHalf = i % 8 == 0;
        final isQuarter = i % 4 == 0;
        final h = isInch ? 40.0 : (isHalf ? 30.0 : (isQuarter ? 22.0 : 14.0));
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h),
          isInch || isHalf ? majorPaint : minorPaint,
        );
        if (isInch) {
          tp.text = TextSpan(
            text: '${i ~/ 16}"',
            style: baseStyle.copyWith(color: color),
          );
          tp.layout();
          tp.paint(canvas, Offset(x + 2, h + 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.pxPerMm != pxPerMm || oldDelegate.unit != unit;
}

/// Messschieber-Modus: zwei ziehbare Marker ueber dem bestehenden Lineal,
/// zeigt den Abstand zwischen ihnen live an. Bewusst kein Einrasten auf
/// volle mm-Marken - wuerde bei einem nur naeherungsweise kalibrierten
/// Bildschirmlineal eine Scheingenauigkeit vortäuschen.
class _SchieblehreOverlay extends StatefulWidget {
  const _SchieblehreOverlay({
    required this.width,
    required this.leftX,
    required this.rightX,
    required this.pxPerMm,
    required this.unit,
    required this.color,
    required this.onChanged,
  });

  final double width;
  final double leftX;
  final double rightX;
  final double pxPerMm;
  final _Unit unit;
  final Color color;
  final void Function(double left, double right) onChanged;

  @override
  State<_SchieblehreOverlay> createState() => _SchieblehreOverlayState();
}

class _SchieblehreOverlayState extends State<_SchieblehreOverlay> {
  static const double _minGapPx = 4;
  bool? _draggingLeft;

  void _moveTo(double dx, {required bool left}) {
    final clamped = dx.clamp(0.0, widget.width);
    if (left) {
      widget.onChanged(
        math.min(clamped, widget.rightX - _minGapPx),
        widget.rightX,
      );
    } else {
      widget.onChanged(
        widget.leftX,
        math.max(clamped, widget.leftX + _minGapPx),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final distMm = (widget.rightX - widget.leftX).abs() / widget.pxPerMm;
    final resultText = widget.unit == _Unit.mm
        ? '${(distMm / 10).toStringAsFixed(2)} cm'
        : '${(distMm / 25.4).toStringAsFixed(2)}"';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        final dx = details.localPosition.dx;
        _draggingLeft = (dx - widget.leftX).abs() <= (dx - widget.rightX).abs();
      },
      onPanUpdate: (details) {
        final draggingLeft = _draggingLeft;
        if (draggingLeft == null) return;
        _moveTo(details.localPosition.dx, left: draggingLeft);
      },
      onPanEnd: (_) => _draggingLeft = null,
      onTapUp: (details) {
        final dx = details.localPosition.dx;
        final left = (dx - widget.leftX).abs() <= (dx - widget.rightX).abs();
        _moveTo(dx, left: left);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CaliperPainter(
                leftX: widget.leftX,
                rightX: widget.rightX,
                color: widget.color,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Center(
              child: Semantics(
                label: 'Messschieber-Ergebnis: $resultText',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    resultText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

class _CaliperPainter extends CustomPainter {
  _CaliperPainter({
    required this.leftX,
    required this.rightX,
    required this.color,
  });

  final double leftX;
  final double rightX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3;
    canvas.drawLine(Offset(leftX, 0), Offset(leftX, size.height), linePaint);
    canvas.drawLine(Offset(rightX, 0), Offset(rightX, size.height), linePaint);
    _drawHandle(canvas, Offset(leftX, 20), color);
    _drawHandle(canvas, Offset(rightX, 20), color);
  }

  void _drawHandle(Canvas canvas, Offset pos, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(pos.dx, pos.dy - 12)
      ..lineTo(pos.dx - 9, pos.dy)
      ..lineTo(pos.dx + 9, pos.dy)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(pos, 4, paint);
  }

  @override
  bool shouldRepaint(covariant _CaliperPainter oldDelegate) =>
      oldDelegate.leftX != leftX || oldDelegate.rightX != rightX;
}
