import 'package:flutter/material.dart';

import 'info_screen.dart';
import 'tools/compass_screen.dart';
import 'tools/level_screen.dart';
import 'tools/light_meter_screen.dart';
import 'tools/ruler_screen.dart';
import 'tools/sound_meter_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <_ToolTile>[
      _ToolTile('Kompass', Icons.explore, (_) => const CompassScreen()),
      _ToolTile('Lineal', Icons.straighten, (_) => const RulerScreen()),
      _ToolTile('Wasserwaage', Icons.architecture, (_) => const LevelScreen()),
      _ToolTile('Schallpegel', Icons.graphic_eq, (_) => const SoundMeterScreen()),
      _ToolTile('Licht', Icons.wb_sunny_outlined, (_) => const LightMeterScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor-Werkzeugkasten'),
        actions: [
          IconButton(
            tooltip: 'Ueber diese App',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InfoScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Fuenf Werkzeuge, keine Werbung, kein Konto.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [for (final t in tiles) _buildTile(context, t)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _ToolTile tile) {
    return Semantics(
      button: true,
      label: '${tile.label} oeffnen',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: tile.builder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tile.icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(tile.label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTile {
  _ToolTile(this.label, this.icon, this.builder);

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}
