import 'package:flutter/material.dart';

/// Ehrliche Selbstauskunft direkt in der App, nicht nur im Store-Eintrag.
/// Untermauert das Versprechen "keine Werbung, kein Konto, komplett offline"
/// aus concept.md.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Über diese App')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _Point(
              icon: Icons.block,
              title: 'Keine Werbung',
              text:
                  'Keine Banner, keine Vollbildwerbung, nichts, das die Bedienung oder den Zurück-Button blockiert.',
            ),
            _Point(
              icon: Icons.wifi_off,
              title: 'Komplett offline',
              text:
                  'Die App fordert keine Internetberechtigung an. Sie kann technisch nicht nach Hause telefonieren.',
            ),
            _Point(
              icon: Icons.no_accounts,
              title: 'Kein Konto',
              text: 'Kein Login, keine Cloud. Alle Einstellungen bleiben nur auf diesem Gerät.',
            ),
            _Point(
              icon: Icons.rule,
              title: 'Ehrliche Genauigkeit',
              text:
                  'Handy-Sensoren sind nicht geeicht. Jedes Werkzeug zeigt offen, wo die Grenzen liegen, statt Präzision vorzutäuschen.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
