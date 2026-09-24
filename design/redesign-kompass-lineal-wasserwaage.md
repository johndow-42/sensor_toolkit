# Redesign-Konzept: Kompass, Lineal, Wasserwaage

Stand: 2026-09-24. Grundlage: `concept.md` (radikale Ehrlichkeit über Sensorgrenzen, keine Werbung, kein Konto,
minimale Berechtigungen, bewusst schlanker Werkzeugkasten) sowie wörtliches Feedback des Produktverantwortlichen
zu drei der fünf Werkzeuge. Dieses Dokument ist ein Design- und Funktionsanalyse-Durchgang, kein Implementierungscode.
Codereferenzen (`_fallbackPxPerMm`, `_BubblePainter` usw.) verweisen auf den Stand von `lib/tools/*.dart` zum
Zeitpunkt dieser Analyse.

---

## 1. Root-Cause-Diagnose der zwei gemeldeten Bugs

### 1.1 Lineal: "nur eine nackte Zahl, Abstände stimmen nie"

**Befund A — keine Maßeinheit sichtbar.**
`_RulerPainter.paint()` beschriftet im mm-Modus (`_Unit.mm`, der Default-Zustand beim Öffnen des Werkzeugs) jede
Zentimeter-Marke ausschließlich mit der reinen Zahl `'${mm ~/ 10}'` (`ruler_screen.dart`, Zeile ~180), ohne jedes
Einheitssuffix. Der Screenshot `store-assets/screenshots/05-lineal.png` zeigt exakt das gemeldete Bild: "0", "1",
"2" ohne "cm"-Kennzeichnung irgendwo auf dem Bildschirm. Der einzige Ort, an dem die aktuelle Einheit *implizit*
erkennbar wäre, ist der Tooltip des `swap_horiz`-Icons in der AppBar ("Auf Zoll umschalten") — ein Tooltip, den auf
Touch-Geräten praktisch niemand auslöst. Im Zoll-Modus (`_Unit.zoll`) wird die Einheit dagegen korrekt an jeder
Zoll-Marke als Anführungszeichen (`'${i ~/ 16}"'`) mitgeschrieben — das bestätigt, dass es sich um eine reine
Auslassung im mm-Zweig des Painters handelt, keinen grundsätzlichen Konstruktionsfehler. Verschärfend kommt hinzu,
dass die Tick-Beschriftungen mit einer hart codierten `TextStyle(fontSize: 12)` gezeichnet werden statt über
`Theme.of(context).textTheme`, was `theme.dart`s eigenem, explizit dokumentiertem Grundsatz widerspricht ("keine
fixierten Schriftgrößen, die die System-Textskalierung überschreiben"). Die Zahlen sind dadurch für Nutzer mit
größerer Systemschrift nicht mitskaliert und entsprechend leicht zu übersehen — das begünstigt den Eindruck
"da steht ja nur eine nackte Zahl".

**Lösung, Teil 1:** Einheit muss an mindestens zwei Stellen dauerhaft und ohne Interaktion sichtbar sein: (a) direkt
im Bedienelement, das die Einheit umschaltet (nicht nur im Tooltip eines Icons), und (b) am ersten Tick des Lineals
selbst ("0 cm" statt nur "0"). Details in Abschnitt 2.2.

**Befund B — Abstände stimmen nie mit echten Zentimetern überein.**
Das ist kein Rendering-Bug, sondern eine Konsequenz aus `_fallbackPxPerMm()` (Zeile ~51–57):

```
final dpr = MediaQuery.of(context).devicePixelRatio;
final assumedDpi = 160 * dpr;
return assumedDpi / 25.4;
```

`devicePixelRatio` ist **kein Messwert der physischen Bildschirmdichte**, sondern der Skalierungsfaktor der
Android-Dichte-*Bucket*, die der Hersteller dem Gerät zugeordnet hat (mdpi=1.0, hdpi=1.5, xhdpi=2.0, xxhdpi=3.0 …).
Diese Buckets sind grobe, historisch gewachsene Stufen um den Faktor 160 dpi herum, keine Messung der tatsächlichen
Pixel-pro-Zoll-Dichte des jeweiligen Panels. Zwei Geräte mit identischem `devicePixelRatio` (z. B. beide "xxhdpi",
3.0) können real sehr unterschiedliche physische Pixeldichten haben, weil die tatsächliche Dichte von Auflösung
**und** physischer Bildschirmdiagonale abhängt, `devicePixelRatio` aber nur die Bucket-Zuordnung des Herstellers
widerspiegelt. Bei Foldables, "Plus"-Modellen und Nicht-Referenz-Auflösungen ist die Abweichung zwischen `160×dpr`
und der echten Pixeldichte in der Praxis regelmäßig zweistellig in Prozent. `_fallbackPxPerMm` ist damit strukturell
eine grobe Heuristik, keine Kalibrierung — und genau das steht auch im bestehenden Hinweistext ("Noch nicht
kalibriert, benutzt eine grobe Schätzung"). Der gemeldete Bug ist also: **die App fällt für die meisten Nutzer
dauerhaft auf diese Heuristik zurück**, weil die echte Kalibrierung schlecht auffindbar ist:

- Der Kalibrieren-Einstieg ist ein kleines, unbeschriftetes Icon (`Icons.straighten`) neben dem Einheiten-Umschalter
  in der AppBar, ohne Onboarding, ohne aktive Aufforderung beim ersten Öffnen.
- Der einzige Hinweis auf den unkalibrierten Zustand ist eine passive, gleich gestaltete `AccuracyNotice`-Box ganz
  unten am Bildschirmrand — visuell nicht dringlicher als jeder andere Genauigkeitshinweis in der App.
- Ergebnis: Ein Nutzer, der die App öffnet, ein Objekt misst und wieder schließt, hat mit sehr hoher
  Wahrscheinlichkeit nie kalibriert und sieht dauerhaft Werte auf Basis der `160×dpr`-Schätzung — exakt das
  gemeldete "die Abstände sind niemals ein cm".

**Lösung, Teil 2:** Zwei unabhängige Hebel, beide nötig: (1) die Kalibrierung selbst auffindbarer und schneller
erfolgreich machen (aktive Aufforderung statt passiver Fußnote, einfachere Referenzobjekte, siehe 2.2), und (2)
den unkalibrierten Zustand ehrlicher/dringlicher kommunizieren, statt ihn wie einen gewöhnlichen Genauigkeitshinweis
aussehen zu lassen. Die Kalibrierungs-*Methode* selbst (Abgleich gegen eine Kreditkarte, 85,6 mm) ist fachlich
korrekt und deckt sich mit `concept.md` — sie muss nicht ersetzt, sondern muss *gefunden und benutzt* werden.

### 1.2 Wasserwaage: "Umschaltung funktioniert nicht"

Kein reiner Anzeige-Bug, sondern zwei sich verstärkende Ursachen — eine echte Darstellungslücke im Painter plus
eine im Alltag oft unauffällige Zahlenänderung:

**Ursache A (Haupt-Ursache) — der Painter stellt beide Modi identisch dar.**
`_LevelScreenState._buildLevel()` berechnet `displayAngle` korrekt modusabhängig (`rollDeg` im `aufrecht`-Modus,
`pitchDeg` im `flach`-Modus, Zeile ~114) — der zugrunde liegende Wert ändert sich bei jedem Tap auf den Umschalter
tatsächlich. Das Problem liegt im `_BubblePainter` (Zeile ~176–214): Er zeichnet **unabhängig vom Modus** exakt
dieselbe Grafik — einen Kreisring mit einer Blase, die einzig entlang der Y-Achse verschoben wird:

```
final bubbleCenter = Offset(center.dx, center.dy - clamped * (radius - 24));
```

`center.dx` ist hartcodiert fix; die X-Position der Blase ändert sich nie, in keinem der beiden Modi. Es gibt keinen
`if (mode == ...)`-Zweig, keine andere Form, keine andere Achsenausrichtung — der Wechsel zwischen `flach` und
`aufrecht` verändert nur (a) das Icon in der AppBar (`stay_current_landscape` ↔ `stay_current_portrait`) und (b) die
Nachkommastelle der Zahl unter dem Kreis. Für einen Nutzer, der auf die große kreisförmige Grafik schaut (das
optisch dominante Element), sieht ein Tastendruck auf den Umschalter buchstäblich nach **nichts** aus — daher
"funktioniert nicht". Das ist ein echtes visuelles Defizit, kein Wahrnehmungsfehler des Nutzers.

**Ursache B (verstärkend) — die zweite Achse wird berechnet, aber nie in der Grafik verwendet.**
Der Code berechnet zusätzlich `secondaryAngle` (die jeweils andere Achse) und zeigt sie als Text an ("Querachse:
X,X°"), speist sie aber **nicht** in den Painter ein — `_BubblePainter` bekommt nur `angleDeg`, nicht die zweite
Achse. Die Blase bewegt sich also grundsätzlich immer nur eindimensional (rauf/runter), unabhängig davon, dass das
Gerät physikalisch in zwei Achsen kippen kann und die App das auch misst. Das verschärft den Eindruck der
Wirkungslosigkeit zusätzlich: Selbst wenn ein Nutzer das Gerät seitlich kippt, bewegt sich die Blase nicht seitlich,
obwohl "Querachse" unten einen anderen Wert anzeigt.

**Ursache C (situativ) — je nach Haltung kann sich der Zahlenwert kaum sichtbar ändern.**
Wenn ein Nutzer das Gerät in einer Haltung hält, bei der die gerade nicht angezeigte Achse zufällig nahe 0° liegt
(z. B. Gerät liegt flach und beinahe unbewegt auf dem Tisch, während der Nutzer zwischen den Modi hin- und
herschaltet, ohne das Gerät neu auszurichten), wechselt der angezeigte Wert selbst kaum sichtbar. Das ist kein Bug,
aber es erklärt, warum manche Testsituationen den Effekt aus Ursache A zusätzlich kaschieren.

**Lösung:** Der Painter muss sich zwischen den Modi *sichtbar formal unterscheiden* (nicht nur der Zahlenwert),
und er muss beide gemessenen Achsen tatsächlich abbilden. Konkretes Verhalten in Abschnitt 2.3.

---

## 2. Visuelles Redesign je Werkzeug

Gemeinsame Leitplanken für alle drei Werkzeuge (aus `concept.md` und `theme.dart` abgeleitet, nicht neu erfunden):

- **Farbschema unverändert lassen.** Weiterhin `ColorScheme.fromSeed(seedColor: 0xFF2E7D6B)` aus `theme.dart`.
  Primärfarbe (Teal) für aktive/hervorgehobene Elemente (Zeiger, aktive Segmente, Kalibrierungs-Fortschritt),
  `onSurface`/`onSurfaceVariant` für Skalen und sekundären Text, `surfaceContainerHighest` für Geräte-/Instrumenten-
  Hintergrundflächen (Zifferblatt, Libellenkörper) — das erzeugt einen dezenten "Instrumenten-Look", ohne neue
  Farbwerte einzuführen. `Colors.green` bleibt als bewusst plattform-unabhängiges Erfolgssignal ("eben"/"level")
  erhalten, exakt wie heute schon in `level_screen.dart` verwendet.
- **Keine hartcodierten Schriftgrößen mehr in Paintern.** Alle Textgrößen aus `Theme.of(context).textTheme` ableiten
  (behebt nebenbei die in 1.1 gefundene Abweichung von `theme.dart`s eigenem Grundsatz).
- **Eine gemeinsame "große Zahl"-Typografie über alle drei Werkzeuge hinweg**, damit die App als ein System wirkt,
  nicht als drei getrennte Bastelprojekte: `displayMedium` (Material-3-Skala, ca. 45sp), fett, mit
  `FontFeature.tabularFigures()` in der `TextStyle`, damit sich wechselnde Ziffern (Grad, Winkel, Länge) nicht
  seitlich verschieben. Aktuell nutzt der Kompass `displaySmall` (36sp) — Anhebung auf `displayMedium` für mehr
  Präsenz und bessere Lesbarkeit auf Armlänge, was insbesondere die Kompass-Peilung und die Lineal-Schieblehre
  begünstigt, wo schnelles Ablesen wichtig ist.
- **`AccuracyNotice`/`SensorUnavailableNotice` unverändert als Muster übernehmen.** Keines der drei Werkzeuge
  bekommt einen neuen Hinweis-Widget-Typ für den Normalfall — das bestehende, dauerhaft sichtbare, nicht
  wegklickbare Muster bleibt der einzige Ort für Genauigkeits-/Verfügbarkeitshinweise. Eine einzige begründete
  Ausnahme wird unten vorgeschlagen (Lineal, unkalibrierter Zustand), weil dort zusätzlich zur reinen Information
  eine Handlung ausgelöst werden soll.
- **Mode-/Einheiten-Umschalter werden von reinen Icon-Buttons zu `SegmentedButton`-artigen Bedienelementen mit
  sichtbarer Textbeschriftung** (Material 3 `SegmentedButton`), konsistent über Lineal (cm/Zoll) und Wasserwaage
  (Flach/Aufrecht). Das ist kein kosmetisches Detail, sondern behebt einen Teil beider gemeldeter Bugs: Der Nutzer
  sieht sofort und dauerhaft, welcher Modus aktiv ist, statt es aus einem Icon-Symbol oder einer Zahl erschließen
  zu müssen.

### 2.1 Kompass

**Layout.** Zentrierte kreisförmige Kompassrose (Durchmesser ca. 280–300 dp, etwas größer als die bisherigen 260,
um Platz für zusätzliche Gradbeschriftung zu schaffen), darunter die bestehende `AccuracyNotice`. Kein zusätzliches
Chrome um die Rose herum, keine Werbefläche, keine überflüssigen Kacheln — bewusst weiterhin ein einziger Fokus-
Bereich pro Screen, passend zur "schlank statt vollgestopft"-Linie aus `concept.md`.

**Zifferblatt statt Nadel-only.** Wechsel vom aktuellen "rotierende Nadel in leerem Ring"-Bild zu einem **rotierenden
Zifferblatt mit fixem Zeiger oben** (12-Uhr-Position), dem Stil professioneller Kompass-Apps (z. B. Google Maps-
Kompass):

- Äußerer Ring: Tick-Marken alle 5° (kurz), alle 15° (mittel), alle 30° (lang), gezeichnet direkt im
  `CustomPainter` (kein zusätzliches `Transform.rotate`-Overhead nötig als grundsätzliche Änderung — die bestehende
  Rotation der gesamten Zeichnung bleibt technisch das einfachste Modell, nur der Painter-Inhalt wird reichhaltiger).
- Haupt-Himmelsrichtungen N/O/S/W: fett, größere Beschriftung, `N` farblich hervorgehoben (Primärfarbe), da
  Nordreferenz sicherheitsrelevant für die Nutzung ist (Peilung, Winkel zwischen Wänden).
- Nebenrichtungen NO/SO/SW/NW: kleiner, `onSurfaceVariant`, an ihren jeweils korrekten 45°-Positionen — ersetzt die
  bisherige rein textuelle Ausschreibung ("Nordnordwest") als *einzige* Richtungsangabe; die ausgeschriebene Form
  bleibt zusätzlich als Text unter der großen Gradzahl erhalten (Screenreader-Kompatibilität, siehe
  `concept.md`-Abschnitt Barrierefreiheit, unverändert wichtig).
- **Fixer Zeiger** (kleines, nicht rotierendes Dreieck/Balken an der 12-Uhr-Position außerhalb des Rings, in
  Primärfarbe): zeigt, wohin das Gerät gerade tatsächlich zeigt, während sich das Zifferblatt darunter dreht. Das
  ist die "seriöse" Variante gegenüber der aktuellen Diamant-Nadel, weil bei einer Nadel leicht verwechselt werden
  kann, welches Ende Norden ist; ein fixer Zeiger mit rotierender Beschriftung macht diese Frage gegenstandslos.
- Zifferblatt-Hintergrund: dezente Kreisfläche in `surfaceContainerHighest` statt reiner Transparenz — gibt dem
  Element räumliche Präsenz ("Instrument" statt "Linienzeichnung"), ohne neue Farben einzuführen.

**Zentrale Anzeige.** Große Gradzahl (`displayMedium`, fett, tabular figures, Suffix "°") über der ausgeschriebenen
Himmelsrichtung (`titleMedium`, wie heute), beides weiterhin über `Semantics` mit vollständigem Text für
Screenreader vorgelesen (Muster unverändert aus dem bestehenden Code übernehmen).

**Zustände:**
- *Laden* (Sensor liefert noch kein Ereignis): statt des generischen `CircularProgressIndicator` ein statisches,
  ausgegrautes Zifferblatt (gleicher Painter, `onSurface`-Opazität 0,15, kein Zeiger) mit Text "Kompass wird
  initialisiert …" darunter — vermittelt sofort die Zielform, statt eine generische Ladeanimation zu zeigen. Optionale
  Verbesserung, kein Pflichtteil des Bugfixes.
- *Nicht verfügbar*: `SensorUnavailableNotice` unverändert weiterverwenden.
- *Geringe Genauigkeit* (`accuracy == null || accuracy > 15`): bestehende `AccuracyNotice`-Logik unverändert
  übernehmen, zusätzlich das Zifferblatt selbst mit reduzierter Opazität (z. B. 0,6 auf allen Tick-Marken und
  Richtungsbuchstaben) zeichnen, damit die Warnung nicht nur unten im Fließtext steht, sondern sich direkt auf dem
  Hauptelement niederschlägt — verstärkt die Transparenz-Philosophie, ohne einen zweiten Hinweistext einzuführen.

### 2.2 Lineal

**Grundproblem zuerst beheben, dann gestalten** — die Neugestaltung darf die in Abschnitt 1.1 diagnostizierten
Lücken nicht nur kosmetisch überdecken:

**Einheit permanent sichtbar machen.**
- Der bisherige `swap_horiz`-IconButton in der AppBar wird durch ein `SegmentedButton<_Unit>` mit den zwei
  sichtbaren Beschriftungen **"cm"** und **"Zoll"** ersetzt (in der AppBar oder direkt darunter als eigene Zeile).
  Die aktuell aktive Einheit ist damit *jederzeit als Text lesbar*, nicht nur aus der Zahlenreihe erschließbar.
- Zusätzlich am Lineal selbst: die erste Zahl der Skala wird nicht mehr als bloßes "0", sondern als "0 cm"
  (bzw. "0″" im Zoll-Modus, dort ist die Einheit durch das Zoll-Zeichen an jeder Marke bereits vorhanden) gezeichnet;
  alle folgenden Zentimeter-Marken bleiben bewusst unbeschriftet außer der Zahl selbst (Standard-Konvention echter
  Lineale) — die Einheit muss nur einmal eindeutig verankert werden, nicht an jeder Marke wiederholt, sonst wirkt
  die Skala überladen.
- Tick-Beschriftungen aus `Theme.of(context).textTheme.labelSmall` statt hartcodierter `fontSize: 12` (behebt den
  in 1.1 genannten Theme-Bruch), Zentimeter-Ticks in voller `onSurface`-Deckkraft/fett, Millimeter-Zwischenticks in
  reduzierter Deckkraft (~0,5) — verbessert Lesbarkeit und Kontrast-Hierarchie gleichzeitig.

**Kalibrierung auffindbar und vertrauenswürdig machen.**
- Solange `_pxPerMm == null` (nie kalibriert): oberhalb der Lineal-Zeichnung erscheint eine **aktive, auffordernde
  Karte** (nicht die neutrale `AccuracyNotice`-Optik, sondern deutlich in `colorScheme.tertiaryContainer` oder
  `errorContainer` abgesetzt) mit Text "Noch nicht kalibriert — Maße stimmen wahrscheinlich nicht" und einem
  direkten `FilledButton` "Jetzt kalibrieren", der sofort in den Kalibrierungs-Modus springt. Die bestehende
  `AccuracyNotice` am unteren Rand bleibt zusätzlich bestehen (sie ist der dauerhafte, ruhige Dauerhinweis; die neue
  Karte ist der einmalige, handlungsauffordernde Zusatz nur im unkalibrierten Zustand). Sobald kalibriert wurde,
  verschwindet die Karte vollständig, die normale `AccuracyNotice` bleibt wie heute als ruhiger Dauerhinweis.
- Kalibrierungsablauf feiner machen: neben dem Slider zwei kleine `+`/`−`-Feinjustierungs-Buttons (± 1 px pro Tipp),
  da ein Slider über die volle Bildschirmbreite bei einer Zielbreite von 85,6 mm sehr grobschrittig ist. Zusätzlich
  während des Ziehens eine kleine Live-Textzeile "aktuell: X,XX px/mm", damit der Vorgang nachvollziehbar und nicht
  wie eine Black Box wirkt (passt zur Transparenz-Philosophie: auch der Kalibrierungs-*Prozess* selbst soll ehrlich
  seine Zwischenwerte zeigen). Der farbige Balken wird als Kreditkarten-Silhouette (abgerundetes Rechteck im
  Kreditkarten-Seitenverhältnis 85,6:53,98 mm) statt als schlichte Farbfläche gezeichnet — erhöht die gefühlte
  Seriosität des Vorgangs.
- **Referenzobjekt-Auswahl statt nur Kreditkarte**: ein kleiner Umschalter im Kalibrierungs-Screen ("Kreditkarte
  85,6 mm" / "A4-Blatt-Breite 210 mm") mit der jeweils passenden Ziel-Silhouette. Begründung und Priorisierung in
  Abschnitt 5 — das ist kein reines Extra, sondern erhöht direkt die Wahrscheinlichkeit, dass überhaupt kalibriert
  wird (nicht jeder hat eine Kreditkarte griffbereit, ein Blatt Papier so gut wie immer).

**Zustände:**
- *Unkalibriert*: aktive Aufforderungskarte wie oben beschrieben plus bestehende `AccuracyNotice` mit präzisierterem
  Text, z. B. "Grobe Schätzung ohne Kalibrierung, Abweichung oft über 20 %" statt der bisherigen vagen Formulierung
  "grobe Schätzung" — konkrete Zahl statt Pauschalaussage ist stärker im Sinne von `concept.md`s "radikaler
  Transparenz".
- *Kalibriert*: `AccuracyNotice`-Text unverändert ("Kalibriert gegen eine Scheckkarte …").
- Kein "nicht verfügbar"-Zustand nötig (reine Bildschirmzeichnung, kein Hardware-Sensor beteiligt).

### 2.3 Wasserwaage

**Ziel:** Die App soll aussehen wie eine echte Wasserwaage (Libellen-/Röhrenform), und die beiden Modi müssen sich
allein an der Form unmittelbar unterscheiden, ohne dass der Nutzer Zahlen lesen oder das AppBar-Icon deuten muss.

**Flach-Modus (Gerät liegt auf einer horizontalen Fläche).**
Beibehaltung einer **kreisrunden Dosenlibelle** — das ist tatsächlich die korrekte, reale Bauform für eine
zweiachsige horizontale Ausrichtung (echte "Dosenlibellen" an Stativen/Wasserwaagen sehen exakt so aus), sie muss
nur ehrlicher gezeichnet werden:
- Zwei bis drei konzentrische Ringe (z. B. bei 0,5°, 1°, 2° Toleranz) statt eines einzelnen Rings, damit die Distanz
  der Blase vom Zentrum eine ablesbare Bedeutung bekommt (wie bei einer echten Dosenlibelle mit Kalibrierungskreis).
- **Die Blase bewegt sich jetzt auf beiden Achsen** (`dx` aus `secondaryAngle`, `dy` aus `displayAngle` abgeleitet,
  jeweils auf denselben Toleranzbereich geklemmt) — behebt den in 1.2 (Ursache B) gefundenen Fehler, dass die zweite
  Achse zwar gemessen, aber nie gezeichnet wird.
- Ausschlagbereich enger fassen: Anschlag bei ±10° statt der aktuellen ±45°. Ein realer Blasenlibellen-Ausschlag ist
  in der Nähe von 0° am aussagekräftigsten; ±45° Anschlag macht die Blase bei alltäglichen kleinen Abweichungen
  (1–5°) kaum sichtbar bewegt — ±10° macht das Instrument im praktisch relevanten Bereich deutlich feinfühliger und
  "seriöser" ablesbar.

**Aufrecht-Modus (Gerät wird an eine Wand/Lot gehalten).**
Komplett andere Form: eine **längliche Röhrenlibelle** (abgerundetes Rechteck, Hochformat, z. B. 90 × 320 dp),
die exakt dem Bild einer klassischen Wasserwaagen-Libelle für Lotmessung entspricht:
- Zwei feste horizontale Referenzlinien in der Mitte der Röhre (Primärfarbe), die die Toleranzzone markieren
  (analog zu den beiden Strichen auf einer echten Libelle, zwischen die die Blase muss).
- Eine kreisrunde Blase, die **innerhalb der Röhre nur vertikal** wandert (Ausschlag ebenfalls auf ±10° geklemmt),
  Füllfarbe wechselt von Primärfarbe zu Grün, sobald sie zwischen den Referenzlinien steht (`isLevel`-Logik
  unverändert wiederverwendbar).
- Kleine Gradmarken links/rechts der Röhre alle 2–3° bis zum Anschlag, im gleichen visuellen Vokabular wie die
  Kompass-Tickmarken — erzeugt Wiedererkennung über die App hinweg.

Dieser Formwechsel (Kreis ↔ längliche Röhre) ist die eigentliche Behebung von Ursache A aus Abschnitt 1.2: ein
Tastendruck auf den Moduswechsel erzeugt jetzt eine sofort erkennbare, unverwechselbare Formänderung, nicht nur eine
andere Nachkommastelle.

**Sekundärachse weiterhin sichtbar halten.** Im Aufrecht-Modus (Hauptelement = Röhre) wird die jeweils andere Achse
zusätzlich als kleine, deutlich kleinere Dosenlibelle (z. B. 56 dp Durchmesser) in einer Ecke angezeigt — für
Nutzer, die beide Achsen gleichzeitig im Blick behalten wollen (z. B. Regal exakt senkrecht UND nicht nach vorne
gekippt ausrichten), ohne dass diese sekundäre Anzeige mit der primären, modusbestimmenden Form verwechselt werden
kann (deutlich kleiner, reduzierte Deckkraft).

**Modusumschalter.** Ersetzt das bisherige reine Icon (`stay_current_landscape`/`stay_current_portrait`) durch ein
`SegmentedButton` mit sichtbarem Text "Flach" / "Aufrecht" (plus den bisherigen Icons als zusätzliche visuelle
Stütze) — Nutzer sehen sofort, dass ihr Tap registriert wurde, unabhängig davon, ob sie die neue Libellenform schon
gedeutet haben.

**Kalibrierungsstatus ehrlich kennzeichnen.** Unter dem "Nullpunkt hier setzen"-Button ein kleiner, unaufdringlicher
Statustext: "Werksnullpunkt (nicht angepasst)" solange `_offsetX == 0 && _offsetY == 0` seit Installation, sonst
"Eigene Kalibrierung aktiv seit [Datum]" (Datum optional, falls ohnehin gespeichert wird). Begründung: Aktuell
präsentiert die App einen nie kalibrierten Werkszustand optisch identisch zu einem bewusst vom Nutzer eingemessenen
Zustand — genau die Art stillschweigender Ungenauigkeit, die `concept.md` als Vertrauensproblem benennt ("Telefone
liegen nie perfekt eben im Werk").

**Zustände:**
- *Laden*: `CircularProgressIndicator` unverändert (kein Sensor-Startup-Delay-Problem bekannt wie beim Kompass).
- *Nicht verfügbar*: `SensorUnavailableNotice` unverändert.
- Kein gesonderter "geringe Genauigkeit"-Zustand nötig (Beschleunigungssensor liefert kein Accuracy-Feld wie der
  Kompass) — der bestehende, dauerhafte `AccuracyNotice`-Text bleibt unverändert als ständiger Hinweis erhalten.

---

## 3. Kompass: Winkel-Halten-Funktion + Zusatzideen

### 3.1 Winkel-Halten (Kernfunktion aus dem Feedback)

**Bedienelement.** Ein `OutlinedButton.icon` unterhalb des Zifferblatts, Beschriftung "Winkel festhalten", Icon
`Icons.lock_outline` — bewusst im selben visuellen Stil wie der bereits etablierte "Nullpunkt hier setzen"-Button
der Wasserwaage, für Wiedererkennung über die App hinweg. Mindestgröße 48 dp Touch-Ziel.

**Interaktionsmodell (drei Zustände: Live → Haltend → Eingefroren).**

1. **Live** (Normalzustand): Zifferblatt zeigt die aktuelle Peilung wie gewohnt, laufend aktualisiert.
2. **Haltend** (`onTapDown`/Press-and-Hold statt eines einfachen `onTap`, damit "gedrückt halten" wörtlich
   funktioniert, nicht nur ein Umschalt-Klick): Beim Drücken wird die *aktuelle* Peilung als Referenzwert
   gespeichert. Während der Finger auf dem Knopf bleibt und das Gerät gedreht wird, zeigt die große Zahl **nicht**
   mehr die absolute Peilung, sondern die **Differenz seit Drückbeginn** ("Δ 47°"), live mitlaufend. Zusätzlich
   zeichnet der Painter einen zweiten, gestrichelten "Geister"-Zeiger an der ursprünglichen Referenzposition sowie
   einen ausgefüllten Kreissektor (Primärfarbe, reduzierte Deckkraft) zwischen Referenz- und aktueller Position —
   macht den gemessenen Winkel als Fläche sichtbar, nicht nur als Zahl (ähnlich einem Winkelmesser/Geodreieck,
   passt zur "seriösen" Zielästhetik, kein Spielerei-Element).
3. **Eingefroren** (beim Loslassen): Der zuletzt gemessene Delta-Wert bleibt stehen, Zifferblatt-Ticks werden
   sichtbar abgedunkelt (Opazität 0,4), großer Zahlenwert bleibt in voller Deckkraft und wird mit Label "Winkel
   gehalten: 47°" versehen. Ein Ergebnis-Kärtchen erscheint darunter mit den zwei Ausgangswerten ("zwischen 288°
   und 335°") sowie zwei Aktionen: "Neu messen" (zurück zu Live) und "Kopieren" (Wert in die Zwischenablage, für
   Weitergabe an Notiz-Apps — keine eigene Speicherung/Historie in dieser Kernfunktion, siehe Abschnitt 5 zu
   "Verlauf" als separate, niedriger priorisierte Idee). Es gibt **kein** automatisches Zurückspringen nach einer
   Zeitspanne — das widerspräche der "keine stillen Überraschungen"-Linie der App; der Nutzer beendet den
   eingefrorenen Zustand explizit.

**Warum Press-and-Hold statt eines einfachen Start/Stop-Toggles als Primärmechanik:** Für den genannten Use Case
(Winkel zwischen zwei sichtbaren Wänden, Peilung zu einem sichtbaren Ziel) dreht sich der Nutzer typischerweise nur
leicht auf der Stelle, ohne zu laufen — Halten während einer kurzen Drehbewegung ist dafür die direktere, fehler-
unanfälligere Geste (kein "habe ich das Messen vergessen zu beenden"-Risiko). Für Szenarien mit größerer Bewegung
(z. B. Nutzer muss zum zweiten Ziel laufen) ist eine Tap-Start/Tap-Stop-Variante geeigneter — siehe Zusatzidee 3.2.

### 3.2 Weitere Zusatzfunktionen (Brainstorm mit Empfehlung)

1. **Zielmarkierung/Peilung merken, ohne GPS.** Nutzer richtet das Gerät auf ein Ziel, tippt "Ziel markieren"; die
   Peilung wird als benannter Marker auf dem Zifferblatt dauerhaft eingezeichnet (z. B. kleiner Punkt bei der
   gespeicherten Gradzahl), bis er gelöscht wird. Kein Standort, keine Koordinaten, keine neue Berechtigung nötig —
   nur der bereits vorhandene Heading-Wert wird lokal gespeichert. Nutzen: eigenständig sinnvoll (z. B. Fotografie,
   Solaranlagen-Ausrichtung, Wiederfinden einer Blickrichtung), und die Referenzmarken-Mechanik lässt sich technisch
   direkt aus der Halten-Funktion (3.1) wiederverwenden. **Empfehlung: bauen**, siehe Priorisierung in Abschnitt 5.

2. **Start/Stop-Variante der Winkelmessung (statt Dauerhalten).** Ein Tap markiert den Referenzwinkel, ein zweiter
   Tap (nach beliebiger Bewegung/Zeit) das Ergebnis, ohne dass der Finger durchgehend auf dem Knopf bleiben muss.
   Sinnvolle Ergänzung für Szenarien mit größerer Bewegung zwischen den zwei Messpunkten. Da sie dieselbe
   Referenz/Delta-Logik wie 3.1 wiederverwendet, ist der Zusatzaufwand gering. **Empfehlung: später**, als
   Erweiterung von 3.1, nicht als Ersatz — kein eigenständiger Startaufwand wert vor Validierung, dass Nutzer 3.1
   überhaupt in der beschriebenen Form nutzen.

3. **Echte Nordanzeige (Missweisungskorrektur).** `concept.md` verspricht bereits "echte Nordanzeige (nicht nur
   magnetisch)" — das ist im aktuellen Code **nicht umgesetzt**, `event.heading` wird unkorrigiert als magnetische
   Peilung angezeigt. Das ist kein Vorschlag dieses Dokuments, sondern eine bereits bestehende Lücke zwischen
   Versprechen und Umsetzung, die hier nur der Vollständigkeit halber genannt wird, weil sie thematisch zur
   Kompass-Überarbeitung gehört. Eine Korrektur erfordert ein geomagnetisches Modell (z. B. WMM) und dafür den
   ungefähren Standort — das ist eine eigenständige Abwägung wert (Standort-Berechtigung gegen "minimale
   Berechtigungen"-Grundsatz), die den Rahmen dieses Redesigns sprengt. **Empfehlung: separat entscheiden, später**,
   nicht Teil dieses Auftrags, aber im Backlog vermerken.

4. **AR-Kamera-Peilung (Kompass-Overlay auf dem Kamerabild).** Würde eine neue Berechtigung (Kamera) einführen,
   erhöht Komplexität und Angriffsfläche deutlich, und wirkt tendenziell "verspielt"/gimmick-haft statt seriös —
   widerspricht damit unmittelbar der in `concept.md` festgelegten Differenzierung über Schlankheit und minimale
   Berechtigungen. Bräuchte laut `concept.md`s eigener "Nicht bauen"-Regel ohnehin eine neue Marktprüfung vor
   Aufnahme. **Empfehlung: verwerfen.**

---

## 4. Lineal: Zwei-Linien-Messfunktion (Schieblehre) + Zusatzideen

### 4.1 Schieblehre-Modus (Kernfunktion aus dem Feedback)

**Einstieg.** Dritter Icon-Eintrag in der AppBar (z. B. `Icons.straighten` durch ein Paar-Symbol ersetzen, etwa
zwei gegenüberliegende Pfeile) mit Tooltip/Label "Messschieber". Aktiviert einen Overlay-Modus **über** dem
bestehenden Lineal, ersetzt die Lineal-Zeichnung nicht, sondern ergänzt sie (siehe Koexistenz unten).

**Aufbau (Layering).** Zwei Ebenen übereinander:
- Untere Ebene: unveränderte `_RulerPainter`-Zeichnung (Ticks/Zahlen bleiben als Referenz sichtbar).
- Obere Ebene: zwei vertikale, ziehbare Markerlinien ("linker" und "rechter" Marker), jeweils mit einem kleinen
  Griff-Symbol oben (z. B. gefüllter Tropfen/Fähnchen) als Drag-Ziel, plus eine dünne, durchgehende vertikale Linie
  über die volle Höhe des Messbereichs.

**Interaktion.**
- Start-Positionen beim Aktivieren: linker Marker bei 1/4, rechter Marker bei 3/4 der sichtbaren Breite.
- Jeder Marker reagiert auf horizontales Ziehen am Griff (`Drag`), Position wird geklemmt, sodass sich linker und
  rechter Marker nicht überkreuzen können (Mindestabstand z. B. 4 px) — verhindert ein unsinniges negatives oder
  Null-Ergebnis.
- Zusätzlich: **Tap an beliebiger Stelle auf dem Lineal** bewegt automatisch den *näherliegenden* der beiden Marker
  an die Tap-Position — schnellere Alternative zum Ziehen aus der aktuellen Position über eine größere Distanz,
  aus Sicht der Bedienbarkeit ein wichtiger Teil des Kernmodells, keine optionale Ergänzung.
- **Bewusst kein hartes Einrasten auf volle Millimeter-Marken.** Ein leichter visueller Hinweis (kurzes Aufleuchten
  der nächstgelegenen Tick-Marke, wenn ein Marker sie auf 2 px genau passiert) ist erlaubt, ein echtes Snapping
  jedoch nicht, weil es bei einem grundsätzlich nur näherungsweise kalibrierten Bildschirmlineal eine Scheingenauig-
  keit erzeugen würde, die der "radikalen Ehrlichkeit über Sensorgrenzen"-Linie aus `concept.md` widerspricht.

**Ergebnisanzeige.** Großer Zahlenwert (gleiche `displayMedium`-Typografie wie Kompass/Wasserwaage, für
Konsistenz), fest oben *oder* unten positioniert (nicht zwischen den Markern, damit er nicht vom ziehenden Finger
verdeckt wird), live aktualisiert aus `(rechteX − linkeX) / pxPerMm`, in der jeweils aktiven Einheit (cm/Zoll)
formatiert. Ein kleiner `Icons.refresh`-Button setzt beide Marker auf die Startpositionen zurück.

**Koexistenz mit dem normalen Lineal-Modus.** Reiner An/Aus-Zustand der oberen Ebene — Umschalten zurück auf
"Lineal" blendet Marker und Ergebnisanzeige einfach aus, die Tick-Zeichnung darunter bleibt technisch und optisch
identisch, keine zwei getrennten Screens. Der Schieblehre-Modus erbt automatisch dieselbe Kalibrierung
(`pxPerMm`) und denselben unkalibrierten-Zustand-Hinweis wie das normale Lineal (ergänzter Satz in der
`AccuracyNotice`: "Der Messschieber-Modus verwendet dieselbe Kalibrierung wie das Lineal.").

### 4.2 Weitere Zusatzideen (Brainstorm mit Empfehlung)

1. **Referenzobjekt-Bibliothek für die Kalibrierung** (Kreditkarte / A4-Blattbreite / ggf. Münzgrößen). Bereits in
   Abschnitt 2.2 als Teil der Bugfix-Lösung beschrieben, hier nochmal als Idee eingeordnet, weil sie zugleich echter
   Zusatznutzen ist: erhöht direkt die Wahrscheinlichkeit einer erfolgreichen Kalibrierung, weil nicht jeder eine
   Kreditkarte griffbereit hat, ein Blatt Papier aber fast immer verfügbar ist. **Empfehlung: bauen**, mit hoher
   Priorität, da direkt am diagnostizierten Root Cause ansetzend (siehe Abschnitt 5).

2. **Messverlauf** (letzte 5–10 Messungen mit Zeitstempel, rein lokal, keine Cloud, kein Export-Zwang). Nützlich bei
   wiederholtem Zuschneiden/Vergleichen mehrerer Objekte kurz hintereinander. Technisch günstig (einfache lokale
   Liste, keine neue Abhängigkeit). **Empfehlung: später** — echter, aber kleinerer Nutzen als die Kernfunktion.

3. **Flächen-Modus** (Breite × Höhe durch zwei nacheinander mit der Schieblehre genommene Messungen, Ergebnis in
   cm² angezeigt). Realistischer Nutzen ist durch die physische Bildschirmgröße stark begrenzt — ein Telefon-
   Bildschirm deckt selten mehr als 6–9 cm Kantenlänge ab, ein Flächenmodus ist damit nur für sehr kleine Objekte
   praktikabel, nicht für die naheliegenden Anwendungsfälle wie Fliesen- oder Tapetenflächen. Technisch günstig
   (baut direkt auf der Schieblehre-Logik auf, nur zwei Werte multiplizieren), aber der reale Nutzen ist durch die
   Geräteklasse gedeckelt. **Empfehlung: später**, ehrlich mit begrenztem Anwendungsbereich kommunizieren, falls
   gebaut.

4. **Kombination mit dem Wasserwaage-Winkel** (Kante an eine Linie halten und gleichzeitig deren Neigung zur
   Horizontalen anzeigen). Interessanter Gedanke, aber Werkzeug-übergreifende Verschmelzung zweier bisher
   unabhängiger Screens, nicht explizit nachgefragt, erhöht Komplexität und Kopplung zwischen zwei Modulen deutlich.
   Passt nicht zur in `concept.md` festgelegten klaren Trennung der fünf eigenständigen Werkzeuge.
   **Empfehlung: verwerfen** (bzw. nur bei konkret nachgewiesener Nutzernachfrage neu bewerten).

---

## 5. Funktionale Analyse — Priorisierung über alle drei Werkzeuge

Bewertungsmaßstab: Nutzen für den Nutzer (hoch/mittel/niedrig), Aufwand (niedrig/mittel/hoch, grob geschätzt anhand
Komplexität in reiner Flutter-Zeichnung/State ohne neue Abhängigkeiten), Vereinbarkeit mit `concept.md`
(keine Werbung, kein Konto, minimale Berechtigungen, radikale Ehrlichkeit über Messgenauigkeit).

### Jetzt bauen (behebt gemeldete Bugs direkt oder liefert hohen Nutzen bei geringem Aufwand)

| # | Maßnahme | Werkzeug | Nutzen | Aufwand | Begründung |
|---|---|---|---|---|---|
| 1 | Einheit sichtbar machen (SegmentedButton cm/Zoll, "0 cm"-Beschriftung) | Lineal | sehr hoch | niedrig | Behebt Bug 1 direkt, kein neuer Zustand, reine Darstellung |
| 2 | Kalibrierung aktiv bewerben (Banner-CTA statt passiver Fußnote, Feinjustierung, Live-Vorschau) | Lineal | sehr hoch | niedrig–mittel | Behebt Bug 2 direkt (Auffindbarkeit ist die Hauptursache) |
| 3 | Referenzobjekt-Bibliothek (Kreditkarte + A4) | Lineal | hoch | niedrig–mittel | Senkt die Einstiegshürde zur Kalibrierung zusätzlich, direkt am Root Cause |
| 4 | Ruler-Politur (Kantenmarkierung, Kontrasthierarchie, Theme-Textstile statt harter fontSize) | Lineal | mittel | niedrig | Behebt nebenbei den Theme-Bruch aus 1.1, verbessert Lesbarkeit |
| 5 | Schieblehre-Modus (zwei Marker, Live-Ergebnis) | Lineal | hoch | mittel | Explizit gewünschte Funktion, klar begrenzter Interaktionsraum |
| 6 | Neues Zifferblatt (Ticks, fixer Zeiger, Haupt-/Nebenrichtungen) | Kompass | hoch | mittel | Direkt gemeldete "spartanisch"-Kritik, kein neuer Sensor-/Permission-Bedarf |
| 7 | Winkel-Halten-Funktion (Press-Hold, Delta-Anzeige, Sweep-Sektor) | Kompass | hoch | mittel | Explizit gewünschte Funktion |
| 8 | Zielmarkierung/Peilung speichern | Kompass | mittel–hoch | niedrig–mittel | Kein neues Permission, nutzt vorhandene Referenz-Mechanik aus #7 mit |
| 9 | Röhrenlibelle für Aufrecht-Modus + echte 2-Achsen-Dosenlibelle für Flach-Modus | Wasserwaage | sehr hoch | mittel | Behebt Bug direkt (Ursache A und B aus 1.2), macht Wasserwaage erkennbar als Wasserwaage |
| 10 | SegmentedButton "Flach"/"Aufrecht" statt Icon-only | Wasserwaage | hoch | sehr niedrig | Sofortiges Feedback, dass ein Tap wirkt, sehr günstig zu bauen |
| 11 | Engerer Ausschlagbereich (±10° statt ±45°) | Wasserwaage | mittel | sehr niedrig | Instrumenten-Gefühl, bessere Ablesbarkeit im relevanten Bereich |
| 12 | Kalibrierungsstatus-Indikator ("Werksnullpunkt" vs. "eigene Kalibrierung") | Wasserwaage | mittel | sehr niedrig | Direkt aus der Ehrlichkeits-Philosophie abgeleitet, sehr günstig |

**Empfohlene Bau-Reihenfolge innerhalb "Jetzt":** zuerst 1–4 und 9–12 (das sind die eigentlichen Bugfixes bzw.
Bugfix-nahen Maßnahmen mit dem größten Nutzen/Aufwand-Verhältnis), danach 5–8 (die explizit gewünschten neuen
Funktionen, die auf den überarbeiteten Paintern aufbauen).

### Später (echter, aber kleinerer oder unsicherer Nutzen; nach den Kernpunkten sinnvoll)

| # | Maßnahme | Werkzeug | Nutzen | Aufwand | Begründung |
|---|---|---|---|---|---|
| 13 | Kalibrierungs-Achter-Animation (visuelle Anleitung statt nur Text) | Kompass | mittel | niedrig | Nice-to-have, unterstützt bestehenden Hinweistext, kein Bugfix |
| 14 | Start/Stop-Variante der Winkelmessung | Kompass | niedrig–mittel | niedrig | Ergänzung zu #7, erst nach Validierung von #7 sinnvoll |
| 15 | Echte Nordanzeige/Missweisungskorrektur | Kompass | mittel | hoch | Bereits in `concept.md` versprochen, aber eigene Standort-Permission-Abwägung nötig, sprengt diesen Auftrag |
| 16 | Verlauf gehaltener Winkel (Liste mit Zeitstempel) | Kompass | niedrig | mittel | Nische der Nische, kein expliziter Bedarf erkennbar |
| 17 | Messverlauf (letzte Messungen) | Lineal | niedrig–mittel | niedrig | Günstig, aber nicht Teil des gemeldeten Problems |
| 18 | Flächen-Modus (Breite × Höhe) | Lineal | begrenzt | niedrig | Nutzen durch Bildschirmgröße fundamental gedeckelt |

### Verwerfen (widerspricht der Produktphilosophie oder Aufwand/Nutzen klar unausgewogen)

| # | Maßnahme | Werkzeug | Begründung |
|---|---|---|---|
| 19 | AR-Kamera-Peilung | Kompass | neue Berechtigung (Kamera), gimmick-haft, widerspricht "schlank"/minimale Berechtigungen, bräuchte laut `concept.md` ohnehin neue Marktprüfung |
| 20 | Kombination Lineal-Kante mit Wasserwaage-Winkel | Lineal | Werkzeug-übergreifende Kopplung, nicht nachgefragt, widerspricht der klaren 5-Werkzeuge-Trennung aus `concept.md` |

### Gesamtfazit

Die zwei gemeldeten Bugs (Lineal-Einheit/-Kalibrierung, Wasserwaage-Modusumschaltung) sind beide mit **niedrigem
bis mittlerem** Aufwand behebbar und sollten vor jeder neuen Funktion umgesetzt werden — sie sind der eigentliche
Vertrauensschaden, den `concept.md`s Differenzierung über Ehrlichkeit direkt betrifft (ein Lineal, das nie eine
korrekte cm-Angabe zeigt, widerspricht dem Kernversprechen der App unmittelbar, unabhängig von jeder
Genauigkeits-Fußnote). Die zwei explizit gewünschten neuen Funktionen (Kompass-Winkel-Halten, Lineal-Schieblehre)
sind beide mit vertretbarem Aufwand umsetzbar, ohne neue Berechtigungen, ohne Konto- oder Cloud-Bedarf, und passen
inhaltlich zur bestehenden Werkzeug-Philosophie. Von den Zusatzideen sind Zielmarkierung (Kompass) und
Referenzobjekt-Bibliothek (Lineal) am stärksten empfehlenswert, weil sie entweder direkt am Root Cause ansetzen
oder bereits vorhandene Mechanik ohne neue Berechtigungen weiterverwenden. Die einzige klar abzulehnende Idee ist
die AR-Kamera-Peilung — sie würde eine neue, im aktuellen Konzept bewusst nicht vorhandene Berechtigungsklasse
einführen und liefe der "schlank und fokussiert"-Positionierung zuwider.
