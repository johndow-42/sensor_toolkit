import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/accuracy_notice.dart';

enum _Unit { mm, zoll }

/// Bildschirm-Lineal. Flutters devicePixelRatio allein ergibt keine
/// verlaessliche physische Groesse (siehe concept.md), deshalb Kalibrierung
/// gegen ein bekanntes Referenzobjekt (Kreditkarte, 85,6 mm), Ergebnis lokal
/// gespeichert.
class RulerScreen extends StatefulWidget {
  const RulerScreen({super.key});

  @override
  State<RulerScreen> createState() => _RulerScreenState();
}

class _RulerScreenState extends State<RulerScreen> {
  static const _prefsKey = 'ruler_px_per_mm';
  static const double _cardWidthMm = 85.6;

  double? _pxPerMm;
  bool _calibrating = false;
  double _calibrationWidthPx = 300;
  _Unit _unit = _Unit.mm;

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
    final pxPerMm = _calibrationWidthPx / _cardWidthMm;
    await prefs.setDouble(_prefsKey, pxPerMm);
    if (!mounted) return;
    setState(() {
      _pxPerMm = pxPerMm;
      _calibrating = false;
    });
  }

  double _fallbackPxPerMm(BuildContext context) {
    // Grobe Schaetzung ueber die logische Displaydichte, nur als Notloesung
    // vor der ersten Kalibrierung. Nicht verlaesslich, siehe Hinweistext.
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
          IconButton(
            tooltip: _unit == _Unit.mm ? 'Auf Zoll umschalten' : 'Auf mm umschalten',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => setState(() {
              _unit = _unit == _Unit.mm ? _Unit.zoll : _Unit.mm;
            }),
          ),
          IconButton(
            tooltip: 'Kalibrieren',
            icon: const Icon(Icons.straighten),
            onPressed: () => setState(() => _calibrating = true),
          ),
        ],
      ),
      body: SafeArea(
        child: _calibrating ? _buildCalibration(context) : _buildRuler(context),
      ),
    );
  }

  Widget _buildCalibration(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Halte eine Scheckkarte (85,6 mm breit) an den Bildschirm und ziehe den Regler, bis der Balken genau so breit ist wie die Karte.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            width: _calibrationWidthPx,
            height: 54,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Slider(
            min: 100,
            max: MediaQuery.of(context).size.width - 20,
            value: _calibrationWidthPx.clamp(100, MediaQuery.of(context).size.width - 20),
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
    final calibrated = _pxPerMm != null;
    final pxPerMm = _pxPerMm ?? _fallbackPxPerMm(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: CustomPaint(
              size: Size.infinite,
              painter: _RulerPainter(
                pxPerMm: pxPerMm,
                unit: _unit,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        AccuracyNotice(
          text: calibrated
              ? 'Kalibriert gegen eine Scheckkarte. Gilt nur fuer diesen Bildschirm, nicht uebertragbar auf andere Geraete.'
              : 'Noch nicht kalibriert, benutzt eine grobe Schaetzung. Tippe oben auf das Lineal-Symbol, um mit einer Scheckkarte zu kalibrieren.',
        ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.pxPerMm, required this.unit, required this.color});

  final double pxPerMm;
  final _Unit unit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    if (unit == _Unit.mm) {
      final stepPx = pxPerMm;
      var mm = 0;
      for (double x = 0; x < size.width; x += stepPx, mm++) {
        final isCm = mm % 10 == 0;
        final isHalf = mm % 5 == 0;
        final h = isCm ? 40.0 : (isHalf ? 26.0 : 16.0);
        canvas.drawLine(Offset(x, 0), Offset(x, h), linePaint);
        if (isCm) {
          tp.text = TextSpan(text: '${mm ~/ 10}', style: TextStyle(color: color, fontSize: 12));
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
        canvas.drawLine(Offset(x, 0), Offset(x, h), linePaint);
        if (isInch) {
          tp.text = TextSpan(text: '${i ~/ 16}"', style: TextStyle(color: color, fontSize: 12));
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
