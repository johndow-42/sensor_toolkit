import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Eine einzelne Messung mit Zeitstempel, unabhaengig vom Werkzeug.
class TimedReading {
  TimedReading(this.timestamp, this.values);

  final DateTime timestamp;

  /// Spaltenname -> Wert, z. B. {"dB (Mittel)": 42.3, "dB (Max)": 58.1}.
  final Map<String, double> values;
}

/// Schreibt eine Messreihe als CSV und oeffnet den System-Teilen-Dialog.
///
/// Kostenlos und ohne Konto nutzbar (Stand V1, siehe concept.md Abschnitt
/// Monetarisierung, Option 3 ist fuer eine spaetere Version vorgesehen, nicht
/// fuer diesen ersten Build).
class MeasurementExporter {
  MeasurementExporter._();

  static Future<void> exportAndShare({
    required String toolName,
    required List<TimedReading> readings,
  }) async {
    if (readings.isEmpty) {
      throw StateError('Keine Messwerte zum Exportieren vorhanden.');
    }

    final columns = readings.first.values.keys.toList();
    final rows = <List<dynamic>>[
      ['Zeitstempel', ...columns],
      for (final r in readings)
        [
          r.timestamp.toIso8601String(),
          for (final c in columns) r.values[c],
        ],
    ];

    final csvString = csv.encode(rows);

    final dir = await getTemporaryDirectory();
    final safeName = toolName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/$safeName-$stamp.csv');
    await file.writeAsString(csvString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '$toolName Messwerte',
        text: '$toolName Messwerte, ${readings.length} Eintraege',
      ),
    );
  }
}
