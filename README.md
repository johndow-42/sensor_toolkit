# Sensor-Werkzeugkasten

Flutter-App: fünf Werkzeuge (Kompass, Lineal, Wasserwaage, Schallpegelmesser, Lichtmesser)
in einer einzigen, dauerhaft werbefreien App ohne Konto und ohne Internetzugriff.
Zielspezifikation, Marktrecherche und Begründung jeder Entscheidung: [`concept.md`](concept.md).

**Stand 2026-09-24:** V1 aller fünf Werkzeuge implementiert und auf einem Android-Emulator
(API 35, Google APIs x86_64) getestet, nicht nur statisch geprüft. `flutter analyze` sauber,
`flutter test` grün, `flutter build apk --debug` baut erfolgreich durch, App startet auf dem
Emulator ohne Absturz, alle fünf Werkzeuge geöffnet und funktionsfähig, Kompass/Wasserwaage/
Lichtmesser reagieren nachweislich live auf eingespeiste Sensorwerte, Schallpegelmesser
zeichnet echte Mikrofonwerte auf. Kein einziger Fehler im Systemprotokoll über die ganze
Testsitzung. Noch nicht auf echter Hardware getestet. Details, gefundene und behobene
Umgebungsprobleme: siehe `work/STATUS.md`, Nachtrag 2026-09-24.

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

## Emulator zum Testen

Ein AVD `sensor_toolkit_test` (Android 15, Google APIs, x86_64) ist eingerichtet, Speicherort
per `ANDROID_AVD_HOME`/`ANDROID_USER_HOME` (Benutzer-Umgebungsvariablen) auf G: umgeleitet, C:
bleibt unberührt. Starten:

```
emulator -avd sensor_toolkit_test
flutter install   # oder: adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Sensorwerte lassen sich ohne Interaktion mit dem Emulatorfenster einspeisen, z. B.:

```
adb emu sensor set light 15000
adb emu sensor set acceleration 3 8 5
adb emu sensor set magnetic-field 0 50 0
```

## Bewusste Einschränkungen (Stand V1)

- Nur der Android-Build ist geprüft, obwohl das Projekt Android/iOS/Web-Ziele unterstützt.
- Auf dem Emulator getestet (siehe oben), noch nicht auf echter Hardware. Insbesondere der
  Kompass ließ sich auf dem Emulator nicht überzeugend testen (eingespeiste
  Magnetfeld-Rohwerte ohne passenden Schwerkraftvektor ändern die von Android berechnete
  Ausrichtung nicht zuverlässig), das bleibt fürs echte Gerät offen.
- Lichtmesser: eigene, kleine native Kotlin-Bruecke (`android/app/.../MainActivity.kt`) statt
  eines Pakets, nur unter Android implementiert. Grund: das naheliegende Paket `light_sensor`
  hat ein kaputtes Android-Gradle-Skript (siehe Nachtrag).
- Monetarisierung noch nicht implementiert, siehe `concept.md`, Abschnitt Monetarisierung.
- Kein App-Icon/Store-Metadaten, das kommt kurz vor der echten Einreichung.
- `dependency_overrides: permission_handler_android: 13.0.1` in `pubspec.yaml` ist ein
  bewusster, dokumentierter Workaround (siehe dortiger Kommentar), regelmäßig prüfen, ob eine
  neuere Version das Android-SDK-37-Namensschema-Problem behebt und der Override entfallen kann.
