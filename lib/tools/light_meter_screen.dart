import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/accuracy_notice.dart';

/// Eigene MethodChannel/EventChannel-Brücke statt eines Drittanbieter-Pakets,
/// siehe Begründung in android/.../MainActivity.kt. Nur unter Android
/// implementiert (Kanal existiert dort nicht -> PlatformException, wird als
/// "nicht verfügbar" behandelt, kein Absturz).
class _LightSensorChannel {
  _LightSensorChannel._();

  static const _method = MethodChannel('sensor_toolkit/light_sensor');
  static const _events = EventChannel('sensor_toolkit/light_sensor/stream');

  static Future<bool> hasSensor() async {
    try {
      final result = await _method.invokeMethod<bool>('hasSensor');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Stream<double> luxStream() {
    return _events.receiveBroadcastStream().map((event) => (event as num).toDouble());
  }
}

class LightMeterScreen extends StatefulWidget {
  const LightMeterScreen({super.key});

  @override
  State<LightMeterScreen> createState() => _LightMeterScreenState();
}

class _LightMeterScreenState extends State<LightMeterScreen> {
  StreamSubscription<double>? _sub;
  double? _lux;
  bool _checking = true;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _checkAndStart();
  }

  Future<void> _checkAndStart() async {
    final hasSensor = await _LightSensorChannel.hasSensor();
    if (!mounted) return;
    if (!hasSensor) {
      setState(() {
        _unavailable = true;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = false);
    _sub = _LightSensorChannel.luxStream().listen(
      (lux) {
        if (mounted) setState(() => _lux = lux);
      },
      onError: (_) {
        if (mounted) setState(() => _unavailable = true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _qualitativeLabel(double lux) {
    if (lux < 1) return 'Nahezu dunkel';
    if (lux < 50) return 'Dämmerlicht';
    if (lux < 200) return 'Gedämpfte Zimmerbeleuchtung';
    if (lux < 500) return 'Normale Zimmerbeleuchtung';
    if (lux < 2000) return 'Helle Arbeitsbeleuchtung';
    if (lux < 10000) return 'Bewölkter Tag im Freien';
    if (lux < 50000) return 'Helles Tageslicht';
    return 'Direktes Sonnenlicht';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lichtmesser')),
      body: SafeArea(
        child: _checking
            ? const Center(child: CircularProgressIndicator())
            : _unavailable
                ? const SensorUnavailableNotice(toolName: 'Der Lichtmesser')
                : _buildReading(context),
      ),
    );
  }

  Widget _buildReading(BuildContext context) {
    final lux = _lux;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: lux == null
                ? const Text('Warte auf ersten Messwert ...')
                : Semantics(
                    label: '${lux.toStringAsFixed(0)} Lux, ${_qualitativeLabel(lux)}',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wb_sunny_outlined,
                            size: 56, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          '${lux.toStringAsFixed(0)} lx',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_qualitativeLabel(lux),
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
          ),
        ),
        const AccuracyNotice(
          text:
              'Handy-Lichtsensoren sind für die Bildschirmhelligkeit gedacht, nicht für Präzisionsmessungen. Werte sind Richtwerte.',
        ),
      ],
    );
  }
}
