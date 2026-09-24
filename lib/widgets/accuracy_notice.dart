import 'package:flutter/material.dart';

/// Wiederverwendbarer, ehrlicher Genauigkeitshinweis. Jedes Werkzeug zeigt ihn
/// dauerhaft sichtbar an (nicht wegklickbar versteckt), weil Transparenz ueber
/// Sensorgrenzen ein Vertrauens-Differenzierungspunkt ist, siehe concept.md.
/// Kein Popup, kein Dialog, blockiert also nie die Navigation oder den
/// Zurueck-Button (siehe concept.md, "staerkster Befund").
class AccuracyNotice extends StatelessWidget {
  const AccuracyNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Hinweis zur Messgenauigkeit: $text',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner fuer "Sensor nicht verfuegbar auf diesem Geraet", statt Absturz.
class SensorUnavailableNotice extends StatelessWidget {
  const SensorUnavailableNotice({super.key, required this.toolName});

  final String toolName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_off, size: 48),
            const SizedBox(height: 12),
            Text(
              '$toolName ist auf diesem Geraet nicht verfuegbar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Dem Geraet fehlt vermutlich der noetige Sensor.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
