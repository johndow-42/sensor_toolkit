// Smoke-Test: Startseite baut fehlerfrei und zeigt alle fuenf Werkzeuge.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:sensor_toolkit/main.dart';

void main() {
  testWidgets('Startseite zeigt alle fuenf Werkzeuge', (WidgetTester tester) async {
    // Grosse Testflaeche, damit alle Kacheln ohne Scrollen im Baum stehen
    // (GridView baut ausserhalb des sichtbaren Bereichs sonst nichts).
    tester.view.physicalSize = const ui.Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SensorToolkitApp());
    await tester.pumpAndSettle();

    expect(find.text('Sensor-Werkzeugkasten'), findsOneWidget);
    expect(find.text('Kompass'), findsOneWidget);
    expect(find.text('Lineal'), findsOneWidget);
    expect(find.text('Wasserwaage'), findsOneWidget);
    expect(find.text('Schallpegel'), findsOneWidget);
    expect(find.text('Licht'), findsOneWidget);
  });
}
