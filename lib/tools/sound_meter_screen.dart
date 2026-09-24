import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../export/measurement_export.dart';
import '../widgets/accuracy_notice.dart';

class SoundMeterScreen extends StatefulWidget {
  const SoundMeterScreen({super.key});

  @override
  State<SoundMeterScreen> createState() => _SoundMeterScreenState();
}

class _SoundMeterScreenState extends State<SoundMeterScreen> {
  final NoiseMeter _meter = NoiseMeter();
  StreamSubscription<NoiseReading>? _sub;
  NoiseReading? _reading;
  double _maxSeen = 0;
  bool _running = false;
  bool _permissionDenied = false;
  String? _error;
  final List<TimedReading> _log = [];

  Future<void> _start() async {
    setState(() {
      _error = null;
      _permissionDenied = false;
    });
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _permissionDenied = true);
      return;
    }
    try {
      _sub = _meter.noise.listen(
        (reading) {
          if (!mounted) return;
          setState(() {
            _reading = reading;
            if (reading.maxDecibel > _maxSeen) _maxSeen = reading.maxDecibel;
            _log.add(TimedReading(DateTime.now(), {
              'dB (Mittel)': reading.meanDecibel,
              'dB (Max)': reading.maxDecibel,
            }));
          });
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() {
            _error = 'Aufnahme fehlgeschlagen: $e';
            _running = false;
          });
        },
        cancelOnError: true,
      );
      setState(() => _running = true);
    } catch (e) {
      setState(() => _error = 'Konnte Mikrofon nicht starten: $e');
    }
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() => _running = false);
  }

  Future<void> _export() async {
    try {
      await MeasurementExporter.exportAndShare(
        toolName: 'Schallpegelmesser',
        readings: _log,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export nicht möglich: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Sicherstellen, dass das Mikrofon nie im Hintergrund weiterläuft, wenn
    // der Bildschirm verlassen wird (Vertrauens- und Datenschutzpunkt).
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schallpegelmesser'),
        actions: [
          IconButton(
            tooltip: 'Messwerte exportieren',
            icon: const Icon(Icons.ios_share),
            onPressed: _log.isEmpty ? null : _export,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: _buildBody(context))),
            const AccuracyNotice(
              text:
                  'Handy-Mikrofone sind nicht geeicht. Die Werte sind Richtwerte, kein Ersatz für ein Messgerät.',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: _running ? _stop : _start,
                icon: Icon(_running ? Icons.stop : Icons.mic),
                label: Text(_running ? 'Stopp' : 'Messung starten'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_permissionDenied) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Ohne Mikrofon-Berechtigung kann nicht gemessen werden.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: openAppSettings,
              child: const Text('App-Einstellungen öffnen'),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, textAlign: TextAlign.center),
      );
    }
    if (_reading == null) {
      return const Text('Bereit. Tippe auf "Messung starten".');
    }
    return Semantics(
      label:
          'Aktueller Schallpegel: ${_reading!.meanDecibel.toStringAsFixed(0)} Dezibel, Maximum ${_maxSeen.toStringAsFixed(0)} Dezibel',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_reading!.meanDecibel.toStringAsFixed(0)} dB',
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Maximum dieser Messung: ${_maxSeen.toStringAsFixed(0)} dB'),
          const SizedBox(height: 4),
          Text('${_log.length} Messpunkte aufgezeichnet',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
