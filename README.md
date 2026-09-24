# Sensor-Werkzeugkasten

Flutter-App: fünf Werkzeuge (Kompass, Lineal, Wasserwaage, Schallpegelmesser, Lichtmesser)
in einer einzigen, dauerhaft werbefreien App ohne Konto und ohne Internetzugriff.
Zielspezifikation, Marktrecherche und Begründung jeder Entscheidung: [`concept.md`](concept.md).

**Stand 2026-09-24:** V1 aller fünf Werkzeuge implementiert. `flutter analyze` sauber,
`flutter test` grün, `flutter build apk --debug` baut erfolgreich durch (160 MB Debug-APK,
noch nicht auf einem echten Gerät getestet, kein Emulator installiert). Details, gefundene und
behobene Umgebungsprobleme: siehe `work/STATUS.md`, Nachtrag 2026-09-24.

## Entwicklung

Toolchain liegt auf `G:\workspace\Webapp\Tools` (Flutter, JDK, Android-SDK), als
Benutzer-Umgebungsvariablen dauerhaft gesetzt, kein zusätzliches Setup nötig.

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Struktur

```
lib/
  main.dart              App-Einstieg, Theme
  theme.dart              Farbschema (hell/dunkel)
  home_screen.dart        Startseite mit den fünf Werkzeug-Kacheln
  info_screen.dart        Ehrliche Selbstauskunft (keine Werbung/Konto/Internet)
  tools/                  Ein Bildschirm je Werkzeug
  widgets/                Wiederverwendbare Hinweis-Widgets
  export/                 CSV-Export mit Zeitstempel (aktuell: Schallpegelmesser)
```

## Bewusste Einschränkungen (Stand V1)

- Nur der Android-Build ist geprüft, obwohl das Projekt Android/iOS/Web-Ziele unterstützt.
- Nur statisch geprüft (Analyzer, Widget-Test, Debug-Build). Kein echtes Gerät und kein
  Emulator verfügbar, deshalb ist noch nicht getestet, ob die Sensoren auf echter Hardware
  plausible Werte liefern (siehe `work/STATUS.md`, Nachtrag 2026-09-24, letzter Punkt).
- Lichtmesser: eigene, kleine native Kotlin-Bruecke (`android/app/.../MainActivity.kt`) statt
  eines Pakets, nur unter Android implementiert. Grund: das naheliegende Paket `light_sensor`
  hat ein kaputtes Android-Gradle-Skript (siehe Nachtrag).
- Monetarisierung noch nicht implementiert, siehe `concept.md`, Abschnitt Monetarisierung.
- Kein App-Icon/Store-Metadaten, das kommt kurz vor der echten Einreichung.
- `dependency_overrides: permission_handler_android: 13.0.1` in `pubspec.yaml` ist ein
  bewusster, dokumentierter Workaround (siehe dortiger Kommentar), regelmäßig prüfen, ob eine
  neuere Version das Android-SDK-37-Namensschema-Problem behebt und der Override entfallen kann.
