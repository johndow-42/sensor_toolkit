# Konzept: Sensor-Werkzeugkasten (Arbeitstitel)

Stand: 2026-09-24. Track pausiert (siehe `work/STATUS.md`, Nachtrag 2026-09-24), dieses Dokument ist die Zielspezifikation,
falls der Track wieder aufgenommen wird, nicht ein Freigabe-Signal zum Bauen.

## Ehrliche Ausgangslage

Drei unabhängige Recherche-Runden haben gezeigt: Der Markt für Sensor-Werkzeugkasten-Apps ist stark besetzt.
Marktführer "Smart Tools" hat über 10 Millionen Installs. Mehrere kostenlose, teils werbefreie Alternativen existieren
bereits (Compass ohne Werbung, Bubble Level PRO, Sound Meter von pony.decibelmeter.soundmeter, Schweizer Taschenmesser,
Smart Toolbox, ToolBox, Sensors Toolbox, Device Sensors & Toolbox). Feature-Vollständigkeit allein löst das
Auffindbarkeits-/Vertrauensproblem gegen etablierte Apps mit jahrelanger Bewertungshistorie nicht.

Der einzige belastbare, noch nicht bestätigt besetzte Spalt aus der Recherche: eine App, die alle fünf Werkzeuge
(Kompass, Lineal, Wasserwaage, Schallpegelmesser, Lichtmesser) in einer einzigen, schlanken, nachweislich und
dauerhaft werbefreien App vereint. Keine der geprüften All-in-one-Apps hatte nachweislich alle fünf UND war
bestätigt werbefrei. Das ist die einzige Zielsetzung, die dieses Konzept verfolgt, kein breiteres Werkzeugkasten-
Sortiment wie bei "Smart Tools" (33 Werkzeuge, dadurch aufgebläht und langsam laut Rezensionen).

**Realistische Erwartung:** Nischenprodukt mit vermutlich niedrigen Downloadzahlen. Sichtbarkeit entsteht am ehesten
über Longtail-Suchbegriffe ("kompass wasserwaage werbefrei alle in einem"), nicht über den breiten Suchbegriff
"Kompass App", wo etablierte Apps dominieren.

## Der stärkste, direkt belegte Befund: der Zurück-Button

Aus der ursprünglichen Recherche (30.118 ausgewertete Rezensionen von 7 populären Sensor-Apps): die häufigste,
am stärksten bestätigte Beschwerde ist nicht Ungenauigkeit, sondern durch Werbung blockierter Zurück-Button
(482 Rezensionen, 1.147 Hilfreich-Stimmen), ein Problem, das selbst der Marktführer nachweislich hat. Das ist die
konkreteste, am besten belegte Anforderung dieses ganzen Konzepts: **niemals** Vollbild-Werbung, Interstitials oder
irgendetwas, das die Navigation unterbricht oder blockiert. Am saubersten: komplett keine Werbung, siehe Monetarisierung.

## Die fünf Werkzeuge

1. **Kompass.** Magnetfeldsensor, echte Nordanzeige (nicht nur magnetisch), Kalibrierungsanleitung bei Abweichung
   (Achtsymbol-Bewegung), Anzeige der Sensorgenauigkeit (`SENSOR_STATUS_ACCURACY_*`), Warnung bei Störung durch
   Metall/Magnete in der Nähe statt stillschweigend falscher Werte.
2. **Lineal.** Bildschirmgröße/DPI-basiert, Kalibrierungsabgleich gegen ein Referenzobjekt (Kreditkarte, 85,6 mm),
   cm/mm/Zoll umschaltbar, Anzeige eines Genauigkeitshinweises (Bildschirmlineale sind nie geeicht).
3. **Wasserwaage.** Beschleunigungssensor, horizontale und vertikale Ausrichtung, Winkelmesser-Modus (0 bis 360 Grad),
   Nullpunkt-Kalibrierung durch den Nutzer speicherbar (Telefone liegen nie perfekt eben im Werk).
4. **Schallpegelmesser.** dB(A)-gewichtet, mit deutlich sichtbarem Kalibrierungshinweis: Handy-Mikrofone sind nicht
   werksseitig geeicht, Werte sind Richtwerte, kein Ersatz für ein Messgerät. Diese Transparenz fehlt bei mehreren
   Konkurrenz-Apps und ist ein Vertrauens-Differenzierungspunkt, keine Ausrede.
5. **Lichtmesser (Lux).** Lichtsensor, mit demselben Transparenz-Hinweis zur Genauigkeit.

Alle fünf in einer gemeinsamen Startseite als Kacheln, kein verschachteltes Menü, App-Start bis zum ersten Messwert
unter 2 Sekunden (Gegenposition zu aufgeblähten 33-Werkzeuge-Apps).

## Vertrauens- und Differenzierungssignale (aus den Erfolgsmustern anderer geprüfter Nischen-Apps)

Aus der dritten Recherche-Runde: Apps, die sich erfolgreich gegen etablierte Konkurrenz mit Abo-/Werbemodell
differenzieren, benutzen konsistent dieselbe Positionierung ("Home Inventory Tracker" gegen Itemtopias Abo-Kritik,
"Lore Lineage" gegen Ahnenforschungs-Abos, mehrere Offline-Apps gegen Cloud-Pflicht). Diese Positionierung 1:1
übernehmen, nicht neu erfinden:

- **Keine Internetberechtigung in der Android-Manifest überhaupt anfordern.** Das ist im Play Store sichtbar und ein
  glaubwürdiges technisches Signal, dass keine Werbe-SDKs oder Tracker verbaut sein können, nicht nur eine Behauptung.
- **Kein Konto, kein Login, keine Cloud-Pflicht.** Alle Einstellungen und Kalibrierungswerte lokal gespeichert.
- **Keine Werbung, kein Tracking-SDK.** Play-Store-Datenschutzangaben entsprechend leer/minimal halten.
- **Einmalkauf statt Abo, falls überhaupt Monetarisierung** (siehe unten), niemals Werbeflächen als Ersatz.
- **Bewusst schlank statt vollgestopft:** fünf Werkzeuge, keine 33, kleine App-Größe als eigenes Verkaufsargument
  in der Store-Beschreibung.

## Monetarisierung, ehrlich eingeordnet

AdMob liegt real bei 0,20 bis 0,80 USD pro 1.000 Impressions (Marktdaten 2026), für eine Nischen-App ohne
Marketingbudget kein tragfähiges Modell, und Werbung widerspricht direkt dem Zurück-Button-Differenzierungspunkt
oben. Realistische Optionen:
1. **Komplett kostenlos, keine Monetarisierung.** Konsequenteste Umsetzung der Differenzierung, aber kein Ertrag.
2. **Einmaliger, niedriger Kaufpreis (kein Freemium, kein Abo)**, zum Beispiel 1,99 Euro. Passt zur Positionierung,
   senkt aber die Downloadzahl weiter (Kaufhürde gegen kostenlose Konkurrenz).
3. **Freemium mit einem einzigen, klar benannten Zusatzfeature hinter einer einmaligen Kauffreischaltung**
   (zum Beispiel Messwert-Export mit Zeitstempel als PDF/CSV, ein Feature, das "Sound Meter" mit Datenexport bereits
   bewirbt und das für Handwerker bei Lärmmessungen echten Nutzen hätte), Kernfunktionen aller fünf Werkzeuge bleiben
   kostenlos und komplett werbefrei.

Empfehlung, falls der Track wieder aufgenommen wird: Option 3, weil sie den Zielspalt (alle fünf, werbefrei) für die
Mehrheit der Nutzer vollständig erfüllt und trotzdem einen realistischen, kleinen Ertragspfad offen lässt, ohne die
Kernpositionierung zu verwässern.

## Barrierefreiheit (kleiner, aber selten gut gemachter Zusatzpunkt)

Hoher Kontrast, Screenreader-Beschriftung aller Messwerte (TalkBack liest "23,4 Grad" statt nur eine Zahl vorzulesen),
Schriftgröße folgt Systemeinstellung. In dieser Nische macht kaum eine Konkurrenz-App das konsequent, geringer aber
echter Aufwand.

## Nicht bauen

Kein Metalldetektor, kein Vibrationsmesser, kein Barometer/Höhenmesser, kein Taschenrechner, keine Taschenlampe,
keine der weiteren 28 Werkzeuge von "Smart Tools". Jede Zusatzfunktion verwässert die "schlank und fokussiert"-
Differenzierung und bräuchte eine eigene neue Marktprüfung, bevor sie aufgenommen wird.
