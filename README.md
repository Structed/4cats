# 4cats

Ein 2D-Spiel aus der Vogelperspektive: Du suchst streunende Katzen, trägst sie
nach Hause und pflegst sie dort gesund, bis sie ein neues Zuhause finden.

Läuft auf **Windows** und **Android** (Handy und Tablet), vollständig mit **Touch**
oder mit Tastatur bedienbar.

| Rettung | Zuhause |
|---|---|
| Streuner suchen, vorsichtig annähern, aufheben | Haus einrichten, Näpfe füllen, Katzen pflegen, Katzenklo reinigen |

## Android installieren und aktuell halten

Mit **Obtainium** bekommst du 4cats direkt aus unseren
[GitHub-Releases](https://github.com/Structed/4cats/releases) und musst neue APKs
nicht selbst suchen. Ein GitHub-Konto oder Zugriffstoken ist normalerweise
nicht nötig.

### Einmal einrichten

1. **Obtainium installieren:** Lade `app-release.apk` aus den
   [offiziellen Obtainium-Releases](https://github.com/ImranR98/Obtainium/releases/latest)
   herunter und installiere sie. Diese APK enthält alle unterstützten
   CPU-Architekturen. Erlaube dem Browser bei Bedarf in Android
   **„Unbekannte Apps installieren“**.
2. **4cats hinzufügen:** Öffne in Obtainium **„App hinzufügen“** und trage
   `https://github.com/Structed/4cats` als **„Quell-URL der App“** ein.
   Die Quelle wird als **GitHub** erkannt. Setze die Optionen wie unten
   beschrieben und bestätige mit **„Hinzufügen“**. Verwende die Repository-URL,
   keinen Link auf eine einzelne Version oder APK.
3. **4cats installieren:** Öffne den neuen Eintrag und installiere `4cats.apk`.
   Erlaube dafür auch **Obtainium** in Android **„Unbekannte Apps installieren“**
   und bestätige die Installation.

| Option für 4cats | Einstellung |
|---|---|
| Sortierverfahren | **Name**, nicht „Intelligenter Name“ oder Datum |
| „Latest“-Tag überprüfen | **Aus** |
| Vorabversionen einbeziehen | **Aus** |
| Nur nachverfolgen | **Aus**, damit Obtainium APKs installieren kann |
| Veröffentlichungsdatum als Version verwenden | **Aus** |
| Versionserkennung deaktivieren | **Aus** – den Release-Tag als Version beibehalten |

Es ist kein Regex-Umschreiben der Version nötig. Warum die Sortierung hier
wichtig ist, steht unter [Versionierung und Obtainium](#versionierung-und-obtainium).

### Updates erhalten

Wähle in Obtainiums **Einstellungen** beim **„Prüfintervall für
Hintergrundaktualisierung“** ein regelmäßiges Intervall statt **„Nie – nur
manuell“**. Erlaube Android-Benachrichtigungen für Obtainium; optional kannst
du **„Einmalig beim Start auf Aktualisierungen prüfen“** einschalten.
4cats darf in seinen Zusatzoptionen nicht von Hintergrundaktualisierungen
ausgeschlossen sein.

Ab **Android 12** sind auch Updates ohne Nachfrage möglich: Aktiviere
**„Stille Installationen im Hintergrund aktivieren“**, falls angeboten.
Voraussetzungen sind unter anderem eine durch Obtainium installierte oder
aktualisierte 4cats-Fassung, ein ausreichend aktuelles Ziel-API-Level der APK
und genau eine passende APK (`4cats.apk`). Andernfalls öffnest du die
Update-Benachrichtigung, startest das Update in Obtainium und bestätigst
Androids Installationsdialog.

**Nicht sofort oder garantiert:** Android kann Hintergrundarbeit verzögern;
auch eine stille Installation kann scheitern. Öffne bei ausbleibenden Updates
Obtainium und prüfe manuell auf Aktualisierungen. Kontrolliere außerdem
WLAN-/Ladeeinschränkungen in Obtainium und Androids Akku-Einstellungen für
Obtainium; erlaube bei Bedarf dessen Hintergrundbetrieb. Die installierte
Version kannst du mit der Anzeige unten rechts im 4cats-Hauptmenü vergleichen.
Details erklärt das [Obtainium-Wiki](https://wiki.obtainium.imranr.dev/app_tracking/#background-updates).

**Schon manuell installiert?** Füge dieselbe Quelle hinzu und installiere das
nächste Release-Update über Obtainium – **ohne vorherige Deinstallation**.
Bei unseren Release-APKs bleibt der Spielstand dabei erhalten. Alte Debug-APKs
haben jedoch eine andere Signatur: Beachte vor einem Wechsel unbedingt die
[Warnung zum Spielstandverlust](#release-signatur-und-wiederherstellung).

## Spielablauf

1. **Rausgehen**: Ein prozedural erzeugtes Viertel mit Straßen, Häusern und Bäumen.
2. **Katzen finden**: Geh in normalem Tempo hin und warte einen Moment – über
   der Katze füllt sich ein Vertrauensbalken. Ist er voll, kannst du sie
   aufheben. Nur **Rennen** (`Shift`) verschreckt Katzen; eine aufgeschreckte
   Katze läuft kurz weg, beruhigt sich aber wieder und behält einen Teil ihres
   Vertrauens. Fliehen ist langsamer als Gehen, du holst sie also immer ein.
3. **Gefahren**: Autos fahren die Straßen entlang, Hunde streunen herum. Wer
   erschrickt, verliert eine getragene Katze – sie läuft weg, mehr passiert nicht.
   Die Rettung hat **kein eigenes Zeitlimit**. Die Versorgung der Hauskatzen
   läuft währenddessen weiter; ihre Risiken hängen vom gewählten Modus ab.
4. **Heimbringen**: Ein grüner Pfeil zeigt dir während der gesamten Rettung den
   Weg nach Hause – am Bildschirmrand oder direkt an der Heimzone, wenn sie im
   Bild ist. Betritt die grün markierte Heimzone, um Katzen abzugeben.
5. **Pflegen**: Zu Hause laufen die Katzen frei herum. Du bewegst dich mit der
   Spielfigur durch das Haus, holst Futter am Vorratsschrank und Wasser am Hahn,
   trägst beides zu den Näpfen und reinigst das
   Katzenklo. Katzen fressen, trinken, spielen und benutzen das Klo selbst.
   Zum Waschen oder Behandeln nimmst du eine Katze auf und trägst sie zur
   passenden Station. Symbole und Animationen zeigen, was sie braucht –
   keine Pflegekarten oder Fortschrittsbalken.
6. **Vermitteln**: Solange Hunger, Durst, Sauberkeit, Gesundheit und
   **Beschäftigung mindestens 80** betragen, sammelt die Katze Genesungsfortschritt.
   Ohne Tierarzt-Ausbau dauert die Genesung bei durchgehend ausreichender Pflege
   **30 Sekunden**; der Ausbau beschleunigt sie. Danach wird die Katze
   **automatisch** vermittelt und bringt Münzen. Getragene Katzen musst du dafür
   erst absetzen. Fällt ein Wert unter 80, sinkt der Fortschritt wieder, statt nur
   zu pausieren. Für die gerade fokussierte oder getragene Katze zeigt eine
   kompakte Zustandsanzeige alle fünf Werte, die Altersgruppe, den
   Genesungsfortschritt und die verbleibende Zeit an. Ein `!` markiert noch
   fehlende Pflege; beim Tragen erinnert die Anzeige daran, die Katze zur
   Vermittlung abzusetzen.
7. **Einrichten und ausbauen**: Näpfe, Vorratsschrank, Wasserhahn, Waschplatz,
   Behandlungsstation, Spielzeug und Katzenklo sind frei auf einem Raster
   platzierbar. Die Grundausstattung sowie weitere Schränke und Wasserhähne
   sind kostenlos; weitere Näpfe, Pflegeplätze, Spielzeug und die Upgrades
   (Tragekorb, Leckerlis, Komfort, Tierarzt) kosten Münzen.

### Leben im Katzenhaus

**Vorräte müssen wirklich geholt werden:** Neue Spiele beginnen mit 24
Futterportionen im gemeinsamen Hausvorrat. Am Schrank nimmst du bis zu zwölf
Portionen auf; am Wasserhahn füllst du ein Gefäß mit bis zu 16 Wasserportionen.
Erst am passenden Napf wird nachgefüllt. Ein voller Napf verbraucht nichts,
Restmengen bleiben auf dem Arm und können an der Quelle zurückgegeben werden.
Futterpakete müssen zuerst in den Schrank eingeräumt werden. Eine Hauskatze und
eine Versorgungsladung lassen sich nicht gleichzeitig auf dem Arm tragen; der
Rettungskorb ist davon unabhängig.

**Nachschub gibt es im begehbaren Laden im Viertel** oder per Bestellung im
Versorgungsdialog zu Hause. Ein Paket enthält 24 Futterportionen. Mehrere
Bestellungen können gleichzeitig unterwegs sein. Jede Lieferung hat ihre eigene
Restzeit; fertige Pakete warten an der Haustür und müssen einzeln abgeholt und
eingeräumt werden. Weder die Ankunft noch das Kaufen eines weiteren Schranks füllt
die Näpfe automatisch.

Wasserholen, Waschen, Behandlung und frische Streu bleiben in allen Modi
kostenlos. Katzen brauchen tatsächlich erreichbare, gefüllte Näpfe und
ausgelegtes Spielzeug. Ein volles Katzenklo wird gemieden und beeinträchtigt
die Sauberkeit der betroffenen Katzen.

Pflege und Lieferungen laufen auch weiter, wenn du draußen Katzen rettest oder
zum Laden gehst. Pause, geöffnete Kaufdialoge und Kataloge, Hauptmenü und
geschlossene App halten beides an; es gibt **keine Offline-Vernachlässigung**
und keine nachträgliche Simulation. Gesundheit verbessert sich durch Behandlung,
nicht automatisch.

### Schwierigkeitsgrade und Alter

Der Modus wird **nur beim neuen Spiel** gewählt und bleibt für diesen Spielstand
fest. Vorausgewählt ist **Entspannt**. Die beiden anderen Modi weisen vor dem
Start ausdrücklich auf möglichen Katzentod hin.

| Modus | Futterpaket / Liefergebühr | Lieferzeit in aktiver Spielzeit | Pflegefolgen |
|---|---|---|---|
| Entspannt | kostenlos / kostenlos | 30 Sekunden | Kein Katzentod, auch nicht bei Vernachlässigung. |
| Anspruchsvoll | 12 / 5 Münzen | 45 Sekunden | Stärkerer Pflegebedarf; mögliche Todesfolge nach kritischer Schonfrist. |
| Realistisch | 16 / 6 Münzen | 60 Sekunden | Höherer Pflegebedarf und kürzere Schonfrist. |

Katzen werden als **Jungtier, erwachsene Katze oder Senior** gerettet. Diese
Altersgruppe bleibt fest: Es gibt kein fortschreitendes Altern und keinen
natürlichen Alterstod. Senioren verlieren in den höheren Modi bei Hunger oder
Durst schneller Gesundheit. Die Rettungs- und Bewegungsgeschwindigkeiten bleiben
für alle Altersgruppen unverändert.

Das HUD warnt auch draußen dauerhaft vor dringendem Pflegebedarf. Sinkt durch
anhaltenden Nahrungs- oder Wassermangel die Gesundheit auf null, beginnt in
Anspruchsvoll eine Schonfrist von 45, in Realistisch von 30 aktiven Sekunden.
Versorgung und Behandlung können die Katze noch retten. Ein Sterbefall wird
namentlich angezeigt und als Verlust gespeichert, bringt aber keine
Vermittlungsbelohnung. Danach kannst du weitere Katzen retten. Wilde Katzen und
Katzen im Rettungskorb erhalten keine zusätzliche Sterbesimulation.

Falls kein Futter mehr verfügbar ist und die Münzen nicht für ein Paket reichen,
kannst du im Laden eine **kostenlose Notration mit sechs Portionen** abholen.
Futter im Schrank, auf dem Arm, in Näpfen (auch eingelagerten) und in bereits
angekommenen Paketen zählt dabei mit. Vorhandene Rationen sperren weitere Hilfe.

### Einrichtung und Spielstände

Beim freien Herumlaufen bleibt die untere Hinweisbox ausgeblendet. Sie erscheint
nur für eine konkrete Aktion in Reichweite, beim Tragen, Pflegen oder Einrichten.
Die kurzen Hinweise lassen mehr vom Haus sichtbar; eine vollständige Übersicht
der Tasten findest du weiterhin im Pausenmenü.

Im Einrichtungsmodus zeigt eine Vorschau vor der Spielfigur den Zielplatz.
Erst die Bestätigung verändert die Einrichtung; Abbrechen lässt alles am
alten Platz. Ausgang, Bedienseiten und Laufwege müssen frei bleiben.
Mit Touch wählst du im Katalog „versetzen“ beziehungsweise „aufstellen“,
bewegst die Vorschau **mit dem sichtbaren Joystick links** und bestätigst
rechts mit „Aufstellen“. Der Gegenstand wird nicht direkt mit dem Finger
gezogen. Den Joystick kannst du beim Bestätigen weiter halten.
Gegenstände lassen sich mit ihrem Vorrat und Zustand einlagern und später
wieder aufstellen. Ein Kauf legt einen Gegenstand ins Inventar; das
anschließende Platzieren kostet nicht erneut.

Spielstände behalten Einrichtung, Inventar, Hausvorrat, Ladung, jede Lieferung
mit ihrer Restzeit, Verschmutzung, Katzenbedürfnisse, Altersgruppen, kritischen
Pflegefortschritt, Verluste und den Modus. Ältere Spielstände werden sicher nach
**Entspannt** übernommen; bestehende Katzen gelten als erwachsen. Katzen,
Münzen, Upgrades und Napfinhalte bleiben erhalten.

Vorratsschrank, Wasserhahn und Startfutter werden bei der Migration einmalig
ergänzt. Neue Stationen werden nur auf freien, erreichbaren Flächen aufgestellt.
Ist kein Platz frei, findest du sie kostenlos im Einrichtungskatalog zum
Aufstellen. Vorhandene Möbel werden nicht ungefragt verschoben.

### Lokale Analytics

Spielstandversion 4 ergänzt **lokale, aggregierte Gameplay-Analytics** unter
`state.analytics` in `user://savegame.json`. Erfasst werden Beschaffung,
Nachfüllen, tatsächlicher Futter-/Wasserverbrauch, Einkaufskosten, Bestellungen,
Ankünfte, Paketabholungen, Einräumen und Notrationen. Kritische Pflegephasen,
erfolgreiches Eingreifen, Vermittlungen und Verluste helfen bei der
Schwierigkeitsbalance; Vermittlungen und Verluste werden nach Katzenaltersgruppe
aufgeteilt (Jungtier, erwachsen, Senior).

Simulierte Spielzeit und aufsummierte Katzensekunden unter der Genesungsschwelle
zeigen Versorgungsengpässe. Pause, Menüs und geschlossene App zählen nicht mit.
Diese lokalen Zähler laufen auch ohne neue Eingaben weiter, solange das Spiel
simuliert; sie sind nicht die AFK-bereinigte Spielzeit der optionalen Nutzungsanalyse.
Abgelehnte Aktionen, wiederholte Paketabholungen und Laden duplizieren keine
Ereignisse. Ältere Spielstände beginnen mit leeren Analytics; historische
Ereignisse werden nicht nachträglich geschätzt.

Diese Spielstandstatistik bleibt **lokal, ohne Netzwerkübertragung und ohne Geräte-
oder Nutzerkennungen**. Sie ist unabhängig von der gesondert zustimmungspflichtigen
[Nutzungsstatistik über PostHog](#optionale-nutzungsstatistik-posthog-eu) und wird
nicht an diese übertragen. Die Statistik enthält auch keine Katzennamen, einzelnen
Katzen-IDs oder Positionsverläufe. Ihre Größe bleibt durch feste Zähler begrenzt.
Ein neues Spiel setzt diese Spielstatistik zurück; bestehende Gesamtzähler für
gerettete und vermittelte Katzen bleiben bei der Migration erhalten.

## Steuerung

| Aktion | PC | Touch |
|---|---|---|
| Gehen | `WASD` / Pfeiltasten | Virtueller Joystick links (erscheint unter dem Daumen) |
| Rennen | `Shift` halten | Knopf „Rennen" rechts (Umschalter) |
| Katze aufheben / Hausaktion | `E` oder `Leertaste` | Kontextknopf rechts unten |
| Einrichten / Vorschau abbrechen | `B` / `Esc` | „Einrichten“ / „Abbrechen“ |
| Gegenstand drehen / einlagern | `R` / `X` | „Drehen“ / „Einlagern“ |
| Gegenstand platzieren | `E` oder `Leertaste` | „Aufstellen“ |
| Pause | `Esc` | „Pause“ im Haus |
| Menüs | Maus | Tippen |

**Wichtig:** Normales Gehen ist ruhig genug – Katzen fassen dabei Vertrauen.
Nur **Rennen** verschreckt sie. Es lohnt sich also, für die letzten Meter vom
Sprint auf Gehen zu wechseln.

Die Touch-Bedienung erscheint automatisch auf Geräten mit Touchscreen. Zum Testen
am PC lässt sie sich unter **Optionen → Touch-Steuerung immer zeigen** erzwingen.

Die **Versionsnummer** steht unten rechts im Hauptmenü. Bei Fehlerberichten
bitte diese Version angeben.

## Aufbau

```
project.godot            Projekteinstellungen (Renderer, Auflösung, Autoloads, Eingaben)
export_presets.cfg       Export-Vorgaben für Windows und Android
scenes/
  main/                  Einstiegsszene
  ui/                    Hauptmenü, HUD, Touch-Bedienung
  rescue/                Rettungs-Level, Spieler, Katze, Gefahren
  home/                  Begehbares Zuhause
scripts/
  autoload/              GameState, SaveManager, AudioManager, SceneRouter, AnalyticsManager
  analytics/             Einwilligung, aktive Spielzeit, Offline-Puffer und HTTPS-Versand
  data/                  Katzen, Hauszustand, Vorräte, Lieferungen und Schwierigkeitsregeln
  rescue/                Spieler, Katzen-Verhalten, Level-Erzeugung, Gefahren
  home/                  Haus-Simulation, Wegfindung, Einrichtung, Versorgung, Pflege und HUD
  ui/                    Menü, HUD, virtueller Joystick
  dev/                   Entwicklungshilfen (nicht Teil des Spiels)
resources/               TileSet und UI-Design
assets/                  Grafik und Ton (siehe CREDITS.md)
tools/                   Skripte zum Bauen, Prüfen und Erzeugen von Assets
.github/
  github-app.yml         Projekteinstellungen für die GitHub-Copilot-App
  actions/setup-godot/   Godot samt Export-Vorlagen in CI installieren
  workflows/ci.yml       Prüfen und Bauen bei jedem Push
  workflows/android.yml  Signiertes APK und Release nach PR-Merge in main
```

### Technische Eckdaten

- **Godot 4.7.2**, GDScript
- Renderer `gl_compatibility` (OpenGL ES 3.0) – größte Abdeckung auf Android
- Basisauflösung 640 × 360, Streckmodus `canvas_items` mit `expand`, damit
  breite Handy-Displays mehr Sichtfeld statt schwarzer Balken bekommen
- Texturfilter `Nearest` (Pixel-Art)
- Android-Paketname `de.structed.fourcats`, Ausrichtung `sensor_landscape`;
  `INTERNET` für die optionale Nutzungsstatistik, keine Werbe-/Hardware-ID-
  Berechtigung. Ohne ausdrückliche Einwilligung gibt es keine Analytics-Anfragen.
- Spielstand als versioniertes JSON in `user://savegame.json`

## Entwicklung

Voraussetzung ist **Godot 4.7.2**. Für den Android-Export zusätzlich
**OpenJDK 17** und das **Android SDK** (Build-Tools 35.0.1, Plattform 35),
konfiguriert in den Godot-Editor-Einstellungen.

Godot liegt selten im PATH. `tools/godot.ps1` sucht die Binary (Umgebungs-
variable `GODOT`, dann PATH, dann die üblichen Installationsorte) und reicht
alle Argumente unverändert weiter. Auf Windows wählt es die Konsolenfassung –
nur sie gibt Ausgaben an die Konsole weiter, was für Testläufe entscheidend ist.

```powershell
pwsh tools/godot.ps1 --which        # zeigt, welche Binary benutzt wird
$env:GODOT = 'C:\Pfad\zu\godot.exe' # überstimmt die Suche
```

Wer Godot im PATH hat, kann in allen folgenden Beispielen `pwsh tools/godot.ps1`
durch `godot` ersetzen.

### Assets holen

Die Kenney-Pakete werden nicht vollständig eingecheckt, nur die genutzten Dateien.
Zum erneuten Beschaffen:

```powershell
pwsh tools/install_assets.ps1
```

Die Katzen-Sprites entstehen aus Pixelkarten und lassen sich einzeln neu erzeugen:

```powershell
pwsh tools/generate_cat_sprites.ps1
pwsh tools/generate_tileset.ps1
pwsh tools/generate_icons.ps1
pwsh tools/generate_home_assets.ps1
```

### Starten und Prüfen

```powershell
# Nach einem frischen Checkout zuerst Ressourcen und Projektklassen importieren
pwsh tools/godot.ps1 --headless --path . --import

# Spiel starten
pwsh tools/godot.ps1 --path .

# Direkt in eine Szene springen
pwsh tools/godot.ps1 --path . -- --start=rescue
pwsh tools/godot.ps1 --path . -- --start=home --demo

# Projektkonfiguration prüfen (Eingaben, Autoloads, Szenen, Versionen)
pwsh tools/godot.ps1 --headless --path . --script res://tools/check_project.gd

# Spiellogik testen (Retten, Pflege, Vorräte, Lieferungen, Modi, Spielstände, Level)
pwsh tools/godot.ps1 --headless --path . -- --test

# Nur Vorräte, Lieferungen, Pflegefolgen und deren Spielstandmigration
pwsh tools\godot.ps1 --headless --path . -- --test --suite=supplies

# Spieltest: Katze einfangen und zu Hause mit echter Steuerung versorgen
pwsh tools/godot.ps1 --headless --path . -- --playtest

# Einzelne echte Spielabläufe gezielt ausführen
pwsh tools\godot.ps1 --headless --path . -- --playtest --suite=home
pwsh tools\godot.ps1 --headless --path . -- --playtest --suite=shop

# Durchlauf: alle Szenen und Knoepfe einmal anfassen
pwsh tools/godot.ps1 --headless --path . -- --smoketest

# Nur Hauptmenü und alle drei Moduswechsel beim Neustart
pwsh tools\godot.ps1 --headless --path . -- --smoketest --suite=menus

# Alle Skripte auf Übersetzungsfehler prüfen
pwsh tools/lint_scripts.ps1

# Automatische Versionsberechnung und APK-Metadaten prüfen
pwsh tools/test_versioning.ps1

# Analytics-Exportkonfiguration und Workflow-Freigaben ohne Netzwerk prüfen
pwsh tools\test_analytics_config.ps1

# Übersichtsbild eines erzeugten Viertels
pwsh tools/godot.ps1 --headless --path . --script res://tools/preview_level.gd -- --out=level.png

# Bildschirmfoto einer Szene
pwsh tools/screenshot.ps1 -Scene home -OutputPath shot.png -Demo

# Touch-Platzierung oder Einrichtungskatalog ansehen
pwsh tools/screenshot.ps1 -Scene home -OutputPath placement.png -Demo -Touch -HomeView placement
pwsh tools/screenshot.ps1 -Scene home -OutputPath catalog.png -Demo -HomeView furnish

# Vermittlungsstatus einer getragenen Katze mit Touch-Bedienung ansehen
pwsh tools\screenshot.ps1 -Scene home -OutputPath cat.png -Demo -Touch -HomeView cat

# Vorräte, mehrere Pakete und die Warnung für einen Senior ansehen
pwsh tools\screenshot.ps1 -Scene home -OutputPath supplies.png -Demo -HomeView supplies
pwsh tools\screenshot.ps1 -Scene home -OutputPath parcels.png -Demo -Touch -HomeView parcel
pwsh tools\screenshot.ps1 -Scene home -OutputPath critical.png -Demo -DemoMode realistic -HomeView critical

# Modusauswahl und begehbaren Laden ansehen
pwsh tools\screenshot.ps1 -Scene menu -OutputPath modes.png -Demo -DemoMode realistic -MenuView difficulty
pwsh tools\screenshot.ps1 -Scene rescue -OutputPath shop.png -Demo -RescueView shop
```

Für Datenschutz- und Optionsansichten unterstützt `tools\screenshot.ps1`
zusätzlich `-MenuView analytics` beziehungsweise `-MenuView options`.
Auch diese visuellen Vorschauen bleiben produktionsgesperrt.

Die Prüfungen geben bei Fehlern Exit-Code 1 zurück und laufen so auch in CI.
Spiel-, Durchlauf- und Logiktests benutzen getrennte temporäre Spielstände
und Einstellungen; auch `--demo` überschreibt keinen normalen Spielstand.

Meldungen wie `Could not find type "CatData"` oder `Identifier "HomeData" not
declared` beim ersten Start weisen auf den noch fehlenden Import-Cache hin.
Den Importbefehl oben ausführen und das Spiel danach neu starten. Der Ordner
`.godot/` wird lokal erzeugt und gehört nicht ins Repository.

Die fünf Prüfungen decken unterschiedliche Fehlerklassen ab:

| Prüfung | Findet |
|---|---|
| `lint_scripts.ps1` | Übersetzungsfehler in **jedem** Skript – auch in Dateien, die im Spiel selten geladen werden |
| `check_project.gd` | Fehlende Eingaben, Autoloads, Szenen; falscher Renderer oder inkonsistente Versionen |
| `--test` | Regeln: Tragen, Hausversorgung, Einrichtung, Vermittlung, Migration, Speichern, Tempo-Verhältnisse |
| `--playtest` | Katze mit echter Physik fangen und über räumliche Pflege zu Hause vermitteln |
| `--smoketest` | Laufzeitfehler in Szenen, Kontextaktionen, Touch-Bedienung, Einrichtung und Menüs |

Zusätzlich prüft `test_versioning.ps1` die Versionsberechnung mit verschiedenen
Git-Merge-Arten, wiederholten Builds und ungültigen Konfigurationen sowie die
Versionskontrolle der APK-Metadaten.

`test_analytics_config.ps1` prüft isolierte Projekt-Fixtures und die echten
Freigabebedingungen der Workflows: standardmäßig aus, strenge Aktivierung,
fehlende/ungültige Angaben, Godot-Escaping, unveränderte Fremdabschnitte,
Zeilenenden/BOM sowie ausgeschaltete PR-/Branch-/manuelle Builds. Es verändert
nicht das echte `project.godot`, verwendet keine Zugangsdaten und sendet nichts.

Der **Spieltest** ist die wichtigste Absicherung für das Rettungs-Gameplay: Er
lädt das echte Level und lässt den Spieler mit echter Physik eine Katze
einfangen. Reine Konstanten-Tests hätten den ursprünglichen Fehler nicht
gefunden – dass der Spieler schneller lief als das Ruhe-Limit der Katzen und
damit *jede* Katze sofort floh.

Der **Linter** ist nötig, weil Godot Parse-Fehler erst meldet, wenn ein Skript
zur Laufzeit gebraucht wird. Er übersetzt jede Datei einzeln mit
`godot --check-only`; Meldungen, die nur an den zur Prüfzeit fehlenden Autoloads
hängen, werden herausgefiltert.

### Fehlerberichte

Das Spiel schreibt jeden Lauf mit. Die Protokolle liegen unter:

```
%APPDATA%\Godot\app_userdata\4cats\logs\        # Windows
~/.local/share/godot/app_userdata/4cats/logs/   # Linux
```

`godot.log` ist der letzte Lauf, daneben liegen die vorherigen mit Zeitstempel.
Wer einen Fehler meldet, hängt am besten die passende Datei an – Godots
Standard von fünf aufbewahrten Protokollen ist bewusst auf 30 erhöht, damit sie
nicht weggerollt sind, bevor jemand nachsehen kann.

### Bauen

Godot legt Zielordner nicht selbst an – vorher anlegen.

Für lokale Builds mit derselben Versionsberechnung wie in CI zuerst
`pwsh tools/set_build_version.ps1` ausführen. Das benötigt die vollständige
Git-Historie und aktualisiert die lokalen Projekt- und Android-Versionsangaben;
Details stehen unter „Versionierung und Obtainium“. Ohne diesen Schritt
verwenden lokale Starts und Exporte die eingecheckte Entwicklungsversion.

```powershell
# Normale lokale Exporte: Analytics ausdrücklich deaktivieren, auch nach
# einem früheren freigegebenen Export. Keine Zugangsdaten erforderlich.
pwsh tools\configure_analytics.ps1

# Windows
mkdir build/windows
pwsh tools/godot.ps1 --headless --path . --export-release "Windows Desktop" build/windows/4cats.exe

# Android (Testfassung, nutzt den Debug-Keystore)
mkdir build/android
pwsh tools/godot.ps1 --headless --path . --export-debug "Android" build/android/4cats.apk
```

Für eine **veröffentlichbare** Android-Fassung wird der dauerhafte
Release-Keystore verwendet (siehe „Release-Signatur und Wiederherstellung“
unten). Er gehört **nicht** ins Repository und darf nicht für jeden Build neu
erzeugt werden. Mit dem eingerichteten Schlüssel unter Windows:

```powershell
$signing = Join-Path $env:LOCALAPPDATA '4cats\signing'
$password = Import-Clixml -LiteralPath (Join-Path $signing 'keystore-password.clixml')
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH     = Join-Path $signing '4cats-release.keystore'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER     = "fourcats"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [pscredential]::new('fourcats', $password).GetNetworkCredential().Password

try {
    New-Item -ItemType Directory -Path build/android -Force | Out-Null
    pwsh tools/godot.ps1 --headless --path . --export-release "Android" build/android/4cats.apk
    if ($LASTEXITCODE -ne 0) { throw 'Android-Release-Export fehlgeschlagen.' }
} finally {
    Remove-Item Env:\GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
    $password.Dispose()
}
```

> **Hinweis zum Android-Emulator:** Der Standard-Emulator mit `swiftshader`
> kann Godots Canvas-Shader nicht übersetzen (`GL_MAX_FRAGMENT_UNIFORM_VECTORS`)
> und zeigt nur ein graues Bild. Mit `emulator -avd <name> -gpu host` funktioniert
> es. Echte Geräte sind davon nicht betroffen.
>
> Das Export-Profil baut für `arm64-v8a` und `armeabi-v7a`. Für einen x86_64-
> Emulator muss `architectures/x86_64` in `export_presets.cfg` vorübergehend
> auf `true` gesetzt werden.

### Automatische Builds

| Wann | Workflow | Ergebnis |
|---|---|---|
| Jeder Push und jeder Pull Request | `ci.yml` | Alle Prüfungen, dazu die versionierte Windows-Fassung als Artefakt `4cats-windows` |
| Sobald ein Pull Request nach **`main` gemergt** wird | `android.yml` | Release-signiertes APK als GitHub Release mit Versions-Tag (z. B. `0.1.12`) und Artefakt `4cats-android-pr<Nummer>` |

Das signierte `4cats.apk` liegt unter
**[Releases](https://github.com/Structed/4cats/releases)** am jeweiligen normalen
Release (kein Prerelease), zusätzlich unter **Actions → Android → Artifacts**.
Gebaut wird genau der Commit, der beim Merge entstanden ist, auch nach einem
Squash- oder Rebase-Merge und bei gemergten Fork-PRs.

Offene oder aktualisierte PRs, ohne Merge geschlossene PRs, direkte Pushes und
Merges in andere Zielbranches erzeugen **weder APK noch Release**. Jeder Merge
nach `main` hat seinen eigenen Release-Tag; ein neuer Merge bricht einen
vorherigen Build nicht ab. Wiederholungen eines Laufs verwenden denselben Tag
und überschreiben weder dessen Commit noch ein bereits vollständig
hochgeladenes Release-APK.

Der Android-Workflow verwendet ausschließlich `--export-release` und prüft die
Signatur gegen den dauerhaften Schlüssel sowie das ausgeschaltete
Debuggable-Flag. Außerdem müssen Paketkennung, Versionsname und Versionscode
im **fertigen APK** den erwarteten Angaben entsprechen. Nur der nachfolgende
Veröffentlichungsjob erhält
`contents: write`; der Build bleibt lesend. Der privilegierte
`pull_request_target`-Auslöser ist auf geschlossene, tatsächlich nach `main`
gemergte PRs beschränkt und checkt niemals einen ungemergten PR-Head aus.

Beide Workflows holen Godot über dieselbe Aktion `.github/actions/setup-godot`.
Eine neue Godot-Version wird deshalb nur in `GODOT_VERSION` der beiden Workflows
geändert, nicht in der Installationslogik.

### Versionierung und Obtainium

`tools/set_build_version.ps1` bildet vor dem Import und Export die gemeinsame
Version für Windows und Android. Die Versionsreihe `MAJOR.MINOR` stammt aus
`application/config/version` in `project.godot` (anfangs `0.1`). Als dritte
Komponente dient die Anzahl der **First-Parent-Commits bis zum gebauten Commit**:
`git rev-list --first-parent --count HEAD`.

Für den Zähler `12` ergeben sich:

| Stelle | Wert |
|---|---|
| Projektversion, Anzeige im Hauptmenü und Android-`versionName` | `0.1.12` |
| Android-`versionCode` | `12` |
| GitHub-Release-Tag | `0.1.12` |
| Release-Titel und APK-Datei | `4cats 0.1.12`, `4cats.apk` |

Der Zähler steigt entlang von `main` auch bei Squash- und Rebase-Merges und
hängt **nicht** von der PR-Nummer oder der Anzahl der Workflow-Versuche ab.
Derselbe Commit erhält in beiden Workflows und bei Wiederholungen dieselbe
Version. Lücken sind erlaubt; bei einer neuen Versionsreihe wird der
Android-Code nicht zurückgesetzt. Beide Workflows laden deshalb die
vollständige Git-Historie. Flache Checkouts werden vom Werkzeug abgelehnt.
Die veröffentlichte `main`-Historie darf nicht nachträglich umgeschrieben
werden, weil dadurch der Zähler zurückgehen könnte.

Die eingecheckten Versionsangaben sind der lokale Entwicklungsstand, anfangs
`0.1.0` mit Android-Code `1`. Die berechneten Build-Werte werden **nicht**
automatisch committed oder zurückgepusht; auch lokal
sollen diese generierten Änderungen nicht als Versions-Bump eingecheckt
werden. Für einen bewussten Wechsel der Versionsreihe die Basisversion in
`project.godot` und die entsprechende Entwicklungsversion `version/name` im
Android-Preset gemeinsam anpassen, ohne den Code hochzusetzen. Die nächste
Build-Vorbereitung setzt wieder die berechnete dritte Komponente und den Code.

Die Schritte zum [Installieren und Aktualisieren mit Obtainium](#android-installieren-und-aktuell-halten)
stehen oben bei der Android-Anleitung.

Das dort verwendete Sortierverfahren **„Name“** sortiert die vollständigen
Tags natürlich, also `0.1.10` nach `0.1.9`, und die alten `android-pr-*`-Tags
vor den neuen numerischen Tags. **„Intelligenter Name“** kann bei gemischten
Formaten die alte PR-Nummer als höhere Version werten. Auch die Datumssortierung
ist ungeeignet, weil ein älterer Merge bei parallelen Builds erst nach einem
neueren veröffentlicht werden kann. Die ausgeschaltete Bevorzugung des
GitHub-„Latest“-Releases sorgt dafür, dass die Versionssortierung maßgeblich bleibt.

Release-Tag und APK-Versionsname stimmen direkt überein; es ist kein
Regex-Umschreiben der Version nötig. Die bisherigen `android-pr-*`-Releases
bleiben erhalten. Neue Versions-Tags ersetzen keine alten Tags oder Assets.
Paketkennung `de.structed.fourcats` und dauerhafter Signaturschlüssel bleiben
gleich, sodass sich bisherige **Release-APKs** ohne Deinstallation und ohne
Verlust des Spielstands aktualisieren lassen. Das gilt nicht für alte
Debug-APKs mit abweichender Signatur (siehe unten).

### Release-Signatur und Wiederherstellung

Unter **Settings → Secrets and variables → Actions** sind diese
Repository-Secrets eingerichtet:

| Secret | Inhalt |
|---|---|
| `ANDROID_RELEASE_KEYSTORE_BASE64` | Dauerhafter JKS-Keystore, Base64-kodiert |
| `ANDROID_RELEASE_KEYSTORE_ALIAS` | Schlüsselalias `fourcats` |
| `ANDROID_RELEASE_KEYSTORE_PASSWORD` | Gemeinsames Keystore- und Schlüsselpasswort |

Der Workflow stellt den Keystore nur vorübergehend in `runner.temp` mit
Dateirechten `0600` bereit und entfernt ihn auch nach einem Fehler. Fehlende
Secrets, ungültige Zugangsdaten oder ein fehlgeschlagener Export brechen den
Build ab; es gibt **keinen Rückfall auf eine Debug-Signatur**.

Der einmalig erzeugte Schlüssel liegt außerhalb des Repositorys unter
`%LOCALAPPDATA%\4cats\signing`, mit Zugriff nur für das zugehörige Windows-Konto:

| Datei | Zweck |
|---|---|
| `4cats-release.keystore` | Privater Release-Schlüssel; nicht ersetzen oder einchecken |
| `keystore-password.clixml` | Passwort als mit Windows DPAPI verschlüsselter `SecureString` |

**Sicherung:** Keystore und Passwort müssen dauerhaft und getrennt vom
Repository sicher aufbewahrt werden. Die Passwortdatei ist an das
Windows-Konto und dessen Maschine gebunden; sie allein ist keine portable
Passwortsicherung. Vor einem Rechnerwechsel das Passwort lokal entschlüsseln
(wie im PowerShell-Beispiel oben) und in einem sicheren Passwortmanager
sichern, ohne es in Logs, Commits oder Chats auszugeben.

Zur Wiederherstellung der Actions-Secrets denselben Keystore mit
`[Convert]::ToBase64String([IO.File]::ReadAllBytes(...))` kodieren, das vorhandene
Passwort lokal aus `keystore-password.clixml` laden und die Werte jeweils über
die Standardeingabe an `gh secret set <Name> --repo Structed/4cats` übergeben.
GitHub gibt gespeicherte Secret-Werte nicht wieder zurück. Vorhandene Schlüssel
oder Secrets deshalb nicht unbesehen neu erzeugen oder überschreiben.

**Wechsel von Debug-APKs:** Die bisherigen Debug-Builds haben eine andere
Signatur und können nicht direkt mit dem Release-APK aktualisiert werden.
Vor einer Installation muss die alte Debug-App entfernt werden; dabei gehen
auch ihre lokalen Spielstände verloren. Künftige Release-APKs verwenden
denselben dauerhaften Schlüssel.

### GitHub-Copilot-App

`.github/github-app.yml` hinterlegt projektbezogene Hinweise und macht die
Befehle oben als Knöpfe verfügbar – Tests, Konfigurationsprüfung, Level-
Übersicht, Windows-Build und das direkte Anspringen einzelner Szenen. Beim
Anlegen einer Sitzung werden die Ressourcen einmal importiert, weil `.godot/`
nicht eingecheckt ist.

Die App wendet die Datei erst an, nachdem man sie einmal geprüft und bestätigt
hat; das gilt nach jeder Änderung erneut.

## Optionale Nutzungsstatistik (PostHog EU)

**Standardmäßig aus und nur nach Opt-in.** Ein ausdrücklich freigegebener
Release-Build zeigt beim ersten Start automatisch eine kurze Abfrage im
Hauptmenü. Sie erklärt in einfachen Worten Zweck, Datenempfänger und
Wiedererkennung der Installation. „Ja, erlauben“ und „Nein danke“ sind
gleichwertig erreichbar; „Mehr zum Datenschutz“ öffnet vor der Entscheidung
die vollständigen Angaben inklusive Betreiberkontakt.

Sowohl Zustimmung als auch Ablehnung werden gespeichert: Bei späteren Starts
wird nicht erneut gefragt. Ablehnen oder Schließen lässt Analytics aus; unter
**Optionen > Nutzungsanalyse** kann die Entscheidung später geändert oder
widerrufen werden. Ohne Einwilligung gibt es weder Messung noch
Installationskennung, Ereignispuffer oder Netzwerkanfrage. Frühere Spielzeit
und bereits erreichter Fortschritt werden nicht nachträglich erfasst.
Spielstände und die Analytics-Entscheidung sind getrennt; „Neues Spiel“
ist kein neuer Nutzer und setzt die Entscheidung nicht zurück.

Die gespeicherte Zustimmung ist an einen Fingerabdruck aus öffentlichem
Projekt-Token, Betreiberkontakt und Hinweisversion gebunden. Ändert sich
einer dieser Werte, werden lokale Kennung und Warteschlange verworfen;
vor weiterer Erfassung ist eine **neue Zustimmung** erforderlich.
Ein bestehender Puffer wird nicht an ein anderes Projekt weitergereicht.
Bereits beim bisherigen Empfänger gespeicherte Daten löscht ein solcher
Konfigurationswechsel nicht.

Nach Zustimmung wird eine zufällige, app-spezifische Installationskennung
erzeugt. Sie ist **pseudonym, nicht die Identität eines Menschen**:
keine Konten, Geräte-/Werbe-IDs, Namen, E-Mail-Adressen, Katzenobjekte,
Positionsverläufe oder Eingabeprotokolle. Keine geräteübergreifende Zuordnung.
Neuinstallation oder erneute Zustimmung nach Widerruf kann eine neue Kennung
erzeugen. Alle Auswertungen beschreiben daher nur die selbst ausgewählte
**Opt-in-Stichprobe**. Daraus lassen sich weder alle Spieler noch eine
Einwilligungsquote bestimmen.

Widerruf stoppt neue Erfassung und neue Requests, bricht einen laufenden
Versand soweit möglich ab und entfernt lokale Kennung und Warteschlange.
**Bereits übertragene Daten werden damit nicht automatisch bei PostHog
gelöscht.** Ein schon empfangener Request lässt sich nicht zurückholen;
für Auskunft und Löschung gilt der Betreiberprozess unten.

Die Implementierung verwendet ausschließlich GDScript und `HTTPRequest`,
kein natives SDK und kein .NET. Der einzige Ingestion-Endpunkt ist fest
`https://eu.i.posthog.com/batch/`; es gibt keine frei konfigurierbare URL.
Editor-, Debug-, Headless-, Test-, Playtest-, Smoketest-, Demo- und Screenshot-
Läufe sowie direkte `--start=`- und Touch-Vorschauen sind unabhängig von
eingebetteten Werten und gespeicherter Zustimmung produktionsgesperrt.
Sie zeigen deshalb keine automatische Freigabeabfrage; die Informationen
bleiben über die Optionen zugänglich.
Feature Flags, Replay und Crash-Reporting gehören nicht
zu dieser Integration.

### Was Spielzeit und Sitzungen bedeuten

- Nur die laufende Spielwelt in `home` oder `rescue` im Vordergrund zählt.
  Pausen, Hauptmenü, Kataloge, Szenenübergänge und App-Hintergrund zählen nicht.
- Nach **120 Sekunden ohne tatsächliche Spieleraktion** endet die Messung;
  die ersten 120 Sekunden zählen. Neue Aktivität trägt die AFK-Lücke nicht nach.
  Gehaltene Tastatur-/Joystick-Bewegung zählt als Aktivität. Timer,
  automatische Vermittlungen und Versandwiederholungen tun das nicht.
  Die Spielsimulation wird durch den Analytics-AFK-Zustand nicht pausiert.
- Eine Sitzung beginnt erst beim Spielen. Prozessneustart oder mindestens
  **30 Minuten ohne Spieleraktivität**, auch in Menü/Pause/Hintergrund,
  führen beim nächsten Spielen zu einer neuen `game_session_id`.
  Das ist eine eigene UUID, **nicht** PostHogs `$session_id`; eingebaute
  PostHog-Sitzungsdauern sind nicht unsere Kennzahl.
- Nicht überlappende positive Zeitdeltas werden alle **60 Sekunden**
  gesichert; Szenenwechsel, Pause/Hintergrund und geordnetes Beenden sichern
  auch den begonnenen Rest. Ein harter Prozessabbruch kann den noch nicht
  gesicherten Rest verlieren. Es gibt kein erforderliches `session_end`.
- Versandversuche erfolgen regelmäßig im **60-Sekunden-Abstand**; der erste
  Batch und weitere volle Batches können früher gesendet werden, damit
  Rückstau auch online abgebaut wird. Höchstens **20 Ereignisse** je Batch,
  ein Request gleichzeitig, begrenzte Wiederholungen/Backoff.
  Offline bleiben höchstens **1.000 Ereignisse, 1 MiB und sieben Tage**
  erhalten; die zuerst erreichte Grenze gilt, älteste/abgelaufene Einträge
  werden zuerst verworfen. Kein unbegrenzter Puffer und keine Exactly-once-
  Zusage. Verlorene Antworten können Wiederholungen erzeugen.
- Fachliche Ereignisse sind nicht an den Spielzeitfilter gebunden: Ein
  erfolgreicher Kauf im pausierten Katalog oder eine echte Abgabe beim
  Szenenwechsel bleibt ein Ereignis, aber erzeugt keine zusätzliche Spielzeit.

### Release-Konfiguration

Die eingecheckten Vorgaben in `project.godot` bleiben:

```ini
[analytics]
enabled=false
project_token=""
privacy_contact=""
```

`tools\configure_analytics.ps1` ändert ausschließlich diese drei vorhandenen
Werte. `-Enabled` ist ein **Switch**: weglassen oder `-Enabled:$false`
deaktiviert Analytics und leert Token/Kontakt, auch wenn die Umgebung
Produktionswerte enthält. Das Skript liest selbst keine Umgebungsvariablen.
Für `-Enabled` müssen `-ProjectToken` und `-PrivacyContact` explizit übergeben
werden. `-ProjectRoot` ist optional und bezeichnet den Ordner mit
`project.godot`; standardmäßig wird das Elternverzeichnis des Skripts benutzt.

Der Token muss syntaktisch `phc_` plus ASCII-Buchstaben/Ziffern entsprechen;
das ist noch keine Bestätigung durch PostHog. Der Kontakt muss nicht leer
und druckbar sein, ohne Steuerzeichen/Zeilenumbrüche; äußerer Leerraum wird
entfernt. Anführungszeichen und Backslashes werden für Godot escaped.
Ungültige aktivierte Konfiguration, fehlende/doppelte Felder oder falsche
Feldtypen brechen **vor dem Schreiben** ab, ohne den Token auszugeben.
Unbeteiligter Text, Kommentare, Zeilenenden und UTF-8-BOM bleiben erhalten.
Eine Freigabe ohne gültige Angaben fällt nicht still auf einen anderen
Schlüssel oder einen scheinbar erfolgreichen Analytics-Build zurück.

Vor einem bewusst freigegebenen lokalen **Release-Export** erst die normalen
Prüfungen ausführen. Die Umgebung im folgenden Beispiel muss der Betreiber
mit den Werten seines getrennten **EU-Testprojekts** vorbereitet haben:

```powershell
try {
    & .\tools\configure_analytics.ps1 -Enabled `
        -ProjectToken $env:POSTHOG_PROJECT_TOKEN `
        -PrivacyContact $env:ANALYTICS_PRIVACY_CONTACT
    New-Item -ItemType Directory -Path build\windows -Force | Out-Null
    pwsh tools\godot.ps1 --headless --path . --export-release "Windows Desktop" build\windows\4cats.exe
    if ($LASTEXITCODE -ne 0) { throw 'Release-Export fehlgeschlagen.' }
} finally {
    & .\tools\configure_analytics.ps1
}
```

Für Android gilt dieselbe Konfiguration unmittelbar vor dem signierten
`--export-release "Android"`; `--export-debug` bleibt gesperrt. Die Werte sind
im Export enthalten, nicht von einer späteren Android-Umgebung abhängig.
Generierte Projektänderungen nicht einchecken. Lokales Zurücksetzen oder
Ändern einer Actions-Variable oder eines Secrets ändert **keine bereits
ausgelieferten Builds**.

Actions verwendet unter **Settings → Secrets and variables → Actions**
folgende, vom Betreiber bewusst einzurichtende Repository-Einstellungen:

| Name | Ablage | Bedeutung |
|---|---|---|
| `ANALYTICS_ENABLED` | **Variables** | Nur exakt `true` aktiviert; leer, `false`, `True`, `1` usw. bleiben aus |
| `POSTHOG_PROJECT_TOKEN` | **Secrets** | Öffentlicher Ingestion-Token des vorgesehenen EU-Projekts |
| `ANALYTICS_PRIVACY_CONTACT` | **Secrets** | Erreichbarer Betreiber-/Datenschutzkontakt für den Hinweis im Build |

Token und Kontakt jeweils über **Secrets → New repository secret** anlegen.
Vorhandene gleichnamige Variables werden nicht mehr gelesen; deren Werte in
die Secrets übernehmen und die alten Variables anschließend entfernen.
Secrets begrenzen die Offenlegung in GitHub und maskieren die Werte in
CI-Logs. Der Kontakt bleibt absichtlich im Datenschutzhinweis des Spiels
sichtbar; der Projekt-Token ist weiterhin aus dem fertigen Client
extrahierbar. Sie sind dadurch nicht im ausgelieferten Spiel geheim.

| Build | Darf bei exakt `true` aktivieren? |
|---|---|
| `ci.yml`: vertrauenswürdiger `push` auf `refs/heads/main` | Ja, erst nach allen Prüfungen, unmittelbar vor dem Windows-Export |
| `ci.yml`: PR, anderer Branch, `workflow_dispatch` (auch auf `main`) | **Nein**, Token und Kontakt werden immer geleert |
| `android.yml`: geschlossener, tatsächlich nach `main` gemergter PR | Ja, ausschließlich im bestehenden Release-Build-Job mit Merge-SHA-Checkout und Signaturprüfungen |
| Normale lokale Builds ohne `-Enabled` / Actions ohne Freigabe | **Nein**, benötigen keine Zugangsdaten |

Die bestehenden Android-Vertrauens- und Signaturgates bleiben unverändert;
ungeprüfter PR-Head-Code wird dort nicht mit Release-Rechten ausgeführt.
Tests/Import laufen vor der Exportkonfiguration. Diese Implementierung legt
keine Konten an, ändert keine Live-Repository-Variablen/Secrets und aktiviert
keinen Dienst automatisch.

### Betreiber- und Datenschutzcheckliste vor Aktivierung

1. Verantwortliche Stelle, Zweck, Empfänger, erreichbaren Kontakt,
   Datenschutzhinweis, Zugriffsrechte und Löschverfahren festlegen.
   Gegebenenfalls Alters-/Elterneinwilligung sowie Store-Datenschutzangaben
   prüfen. Ein katzenfreundliches Spiel und EU-Hosting ersetzen keine
   rechtliche Prüfung.
2. Zuerst ein getrenntes **PostHog-Cloud-EU-Testprojekt**, danach bei Bedarf
   ein Produktionsprojekt einrichten. EU-Datenhaltung ist laut Anbieter in
   **Frankfurt**. Nicht versehentlich einen US-Projekt-Token verwenden.
3. Unter **Settings → Project → IP data capture configuration**
   **Discard client IP data** einschalten **und separat** die
   **GeoIP-Enrichment-Transformation deaktivieren**. IP-Verwerfen verhindert
   nicht automatisch die vorherige GeoIP-Anreicherung. Der empfangende
   Netzwerkserver sieht technisch weiterhin die Quell-IP; nicht „IP wird
   nie übertragen“ versprechen. Im Test tatsächliche gespeicherte
   Eigenschaften und aktive Transformationen kontrollieren.
4. Jedes Ereignis enthält `$process_person_profile=false`.
   Keine Identify-/Alias-/Profiloperationen aktivieren, auch nicht für einen
   Dashboard-Trick. Bereits einmal identifizierte `distinct_id` können bei
   PostHog trotz dieses Flags identifiziert bleiben: nur die app-eigenen
   neuen Kennungen verwenden, nicht mit anderen Produkten vermischen.
5. Nur den **öffentlichen Projekt-Token** ausliefern, niemals Personal-,
   Admin- oder Lösch-API-Keys. Ein öffentlicher Token ist kein Geheimnis und
   kein Schutz vor gefälschten Ereignissen oder fremd verursachten Kosten.
   Analytics ist kein manipulationssicheres Abrechnungs-/Anti-Cheat-System.
6. Den synthetischen Export-/Dashboard-Durchlauf unten und den
   profilfreien Löschprozess prüfen. Erst danach Produktionswerte und die
   ausdrückliche Freigabe setzen. Betreiberkontakt und Projekt-Token wie
   oben als Actions-Secrets hinterlegen. Privilegierte Admin-Zugänge
   bleiben ausschließlich beim berechtigten Betreiber und werden niemals
   in den Spiel-Build eingebettet.

**Auskunft und Löschung:** Anfragen gehen an den eingebetteten
`ANALYTICS_PRIVACY_CONTACT`. Soweit noch bekannt, kann die pseudonyme
Installationskennung (`distinct_id`) zur Zuordnung dienen; eine benötigte
Kennung muss vor dem lokalen Widerruf gesichert werden. Keine zusätzlichen
Geräte-IDs oder Identitätsdaten nur zum späteren Wiedererkennen einführen.
Der Betreiber prüft Anfrage und Zuordenbarkeit, sucht die zugehörigen
Ereignisse und verwendet ein vom Anbieter unterstütztes Löschverfahren mit
seinem getrennten berechtigten Zugang. Erfolg erst nach Abschluss und
Kontrolle der asynchronen Löschung bestätigen.

**Vor Live-Freigabe zu klären:** PostHogs dokumentierter Standard-Löschweg
arbeitet mit Personenprofilen; im hier gewählten Modus gibt es gerade keine.
Die gezielte Löschung profilfreier Ereignisse anhand `distinct_id` muss der
Betreiber mit PostHog klären und im Testprojekt nachweisen. Nicht einfach
„Person löschen“ versprechen oder dafür unbemerkt Profile erzeugen. Falls
kein geeigneter gezielter Weg besteht, muss ein belastbares alternatives
Verfahren (gegebenenfalls Löschung des ganzen Projekts) geklärt sein, bevor
produktiv erfasst wird. Nach Verlust der Kennung ist eine einzelne
Installation gegebenenfalls nicht mehr zuordenbar; diese Grenze offen
kommunizieren. Widerruf, lokales Queue-Löschen und Aufbewahrungsablauf sind
kein Ersatz für die Bearbeitung einer Löschanfrage.

**Kosten und Datenverlust:** Das kostenlose Product-Analytics-Kontingent
umfasst derzeit **eine Million Ereignisse pro Monat**; aktuelle Grenzen und
Preise immer beim Anbieter prüfen. Ein Batch mit 20 Ereignissen bleibt
20 abrechenbare Ereignisse. Der Free-Plan hat derzeit **ein Jahr**
Ereignisaufbewahrung; die Durchsetzung wird projektweise ausgerollt und ist
im konkreten Projekt zu prüfen. Die Frist lässt sich nicht individuell als
Löschwerkzeug verkürzen. Kosten-/Nutzungslimits können weitere Verarbeitung
stoppen und Daten verlieren lassen. Eine erfolgreiche HTTP-Antwort ist
keine Garantie für gespeicherte Ereignisse; verworfene/als empfangen
bestätigte Daten werden nicht automatisch durch die lokale Queue gerettet.
Kontingent, Ingestion-Warnungen und Datenlücken rechtzeitig überwachen.

Quellen:
[Capture-/Batch-API](https://posthog.com/docs/api/capture),
[EU-Speicherung, IP/GeoIP und Löschung](https://posthog.com/docs/privacy/data-storage),
[profilfreie Einschränkungen](https://posthog.com/docs/data/anonymous-vs-identified-events),
[Aufbewahrung](https://posthog.com/docs/data/events-retention),
[aktuelle Preise](https://posthog.com/product-analytics/pricing).

### Ereigniskatalog, Schema 1

Jeder Eintrag in `batch` hat die Wurzelfelder **`event`, `timestamp`,
`properties`**. Der öffentliche Token steht als `api_key` am Batch-Envelope.
`timestamp` ist die **ursprüngliche UTC-Ereigniszeit in ISO 8601**, nicht die
Ankunfts-/Retry-Zeit und nicht bloß eine Eigenschaft innerhalb `properties`.
PostHog übernimmt `properties.distinct_id` in seine Ereignisspalte
`distinct_id`. Beispiel eines Eintrags, ohne echte Kennungen:

```json
{
  "event": "playtime",
  "timestamp": "2026-09-11T12:00:00.000Z",
  "properties": {
    "event_id": "df02cad1-232a-4e14-9f6f-781b5c850d01",
    "distinct_id": "8a47060f-b3ee-4c0f-9250-64861fd1ea12",
    "schema_version": 1,
    "app_version": "0.1.123",
    "platform": "Windows",
    "$process_person_profile": false,
    "game_session_id": "f5a23be1-eb1e-43d9-92a0-8e8aa549f789",
    "duration_seconds": 60.0,
    "scene": "home"
  }
}
```

Alle Ereignisse haben `event_id` (UUID, stabil bei Retry), `distinct_id`
(zufällige Installation), `schema_version=1`, `app_version`,
`platform` (`Windows` oder `Android`) und `$process_person_profile=false`.
Jedes übertragene Ereignis trägt außerdem eine `game_session_id`; Spielzeit
wird der tatsächlichen Spielsitzung zugeordnet. Auch eine erfolgreiche
Spieleraktion im pausierten Katalog kann die erste Sitzung beginnen, ohne
Pausenzeit zu zählen. Bloße Menübesuche erzeugen keine Ereignisse. IDs,
Zeitpunkt und Eigenschaften bleiben bei Offline-Versand und Wiederholungen
unverändert.

| Ereignis | Zusätzliche Eigenschaften | Bedeutung |
|---|---|---|
| `play_session_started` | keine | Tatsächlicher Beginn einer Spielsitzung, nicht bloßer Menüstart |
| `playtime` | `duration_seconds`: positive Zahl; `scene`: `home` / `rescue` | Addierbares Zeitdelta, kein kumulativer Sitzungsstand |
| `game_started` | `kind`: `new` / `continue` | Bewusster Start-/Fortsetzen-Pfad, nicht jedes Laden/Reset |
| `scene_entered` | `scene`: `home` / `rescue` | Erfolgreicher Szeneneintritt |
| `cat_picked_up` | `pickup_location`: `indoor` / `outdoor` | Ein erfolgreicher Pickup; Wiederaufheben ist ein weiterer Pickup |
| `cat_rescued` | keine | Genau einmal je tatsächlich zu Hause abgegebener Katze |
| `cat_adopted` | `reward`: Ganzzahl | Tatsächliche Vermittlung und Belohnung in Spielmünzen |
| `upgrade_purchased` | `upgrade_id`: String; `level`, `price`: Ganzzahlen | Erfolgreicher Ausbau, erreichte Stufe und bezahlter Preis |
| `home_item_purchased` | `kind`: String; `price`: Ganzzahl | Erfolgreicher Einrichtungskauf, nicht Grundausstattung/Versetzen |

**Rettung ist ausschließlich Abgabe:** Eine draußen entkommene und wieder
gefangene Katze ergibt einen weiteren Outdoor-Pickup, aber erst ihre
tatsächliche Lieferung eine Rettung. Drinnen aufheben/absetzen, erneuter
Hausbesuch und Laden erzeugen keine neue Rettung. Mehrere abgegebene Katzen
ergeben je ein `cat_rescued`. Der historische Spielstandzähler
`rescued_total` ist **keine** Quelle für diese Statistik; es gibt kein
zusätzliches Analytics-Ereignis `cats_delivered`.

### Dashboard reproduzierbar einrichten

Im EU-Testprojekt ein Dashboard **„4cats – Opt-in“** anlegen und die folgenden
Abfragen einzeln als SQL-/HogQL-Insights speichern und hinzufügen.
**Projekt- und Dashboard-Zeitzone auf UTC setzen und durchgängig dabei
bleiben.** `toDate(...)`, Tagesgrenzen und Kalender-Rückkehrtage beziehen
sich unten auf diese Einstellung. Für andere Zeitzonen alle Abfragen und
die Projektkonfiguration gemeinsam anpassen; nicht lokale Tage mit UTC
mischen. Immer Ereigniszeit verwenden, nie Upload-Zeit.

Die Abfragen greifen ausschließlich auf `events` zu, nicht auf `persons`,
gespeicherte Personenkohorten oder Lifecycle Insights. Diese Funktionen
stehen im profilfreien Modus nicht zur Verfügung. Kein automatischer
Dashboard-Import und keine zusätzliche Profilaktivierung sind erforderlich.
Native Event-Funnels sind ebenfalls möglich; für belastbare Zähler und
Zeit-/Münzsummen gelten die deduplizierenden SQL-Abfragen hier.

**Gemeinsamer Anfang für jede Abfrage:** Diesen gesamten `WITH e AS (...)`-
Block vor genau einen der nachfolgenden Abfrageblöcke setzen, ohne Semikolon
dazwischen. Ein nachfolgender Block mit führendem Komma ergänzt weitere
CTEs. Die Basis wählt zuerst pro `(distinct_id, event_id)` genau einen
logischen Eintrag. Unveränderte Retry-Kopien werden damit **vor** Zählung,
Summierung oder Sitzungsbildung dedupliziert. Nicht auf implizite
Server-Deduplizierung verlassen.

```sql
WITH e AS (
    SELECT
        distinct_id AS installation_id,
        toString(properties.event_id) AS event_id,
        argMin(event, timestamp) AS event_name,
        min(timestamp) AS occurred_at,
        argMin(toString(properties.game_session_id), timestamp) AS game_session_id,
        argMin(toString(properties.app_version), timestamp) AS app_version,
        argMin(toString(properties.platform), timestamp) AS platform,
        argMin(toFloat(properties.duration_seconds), timestamp) AS seconds,
        argMin(toString(properties.scene), timestamp) AS scene,
        argMin(toString(properties.kind), timestamp) AS kind,
        argMin(toString(properties.pickup_location), timestamp) AS pickup_location,
        argMin(toString(properties.upgrade_id), timestamp) AS upgrade_id,
        argMin(toInt(properties.level), timestamp) AS level,
        argMin(toInt(properties.price), timestamp) AS price,
        argMin(toInt(properties.reward), timestamp) AS reward
    FROM events
    WHERE event IN (
        'play_session_started', 'playtime', 'game_started', 'scene_entered',
        'cat_picked_up', 'cat_rescued', 'cat_adopted',
        'upgrade_purchased', 'home_item_purchased'
    )
      AND toInt(properties.schema_version) = 1
      AND properties.event_id IS NOT NULL
      AND toString(properties.event_id) != ''
    GROUP BY distinct_id, properties.event_id
)
```

Die Basis umfasst die **gesamte noch verfügbare Ereignishistorie**.
Insbesondere für „erstmals beobachtet“ keinen Dashboard-Zeitfilter schon
vor `min(...)` anwenden. Fehlende Pflichtfelder als Erfassungsfehler
untersuchen, nicht stillschweigend aus nicht deduplizierten Rohdaten
ergänzen. Bei langen Historien Query-Kosten und Laufzeit im echten Projekt
prüfen; diese SQL-Blöcke sind keine eingerichteten materialisierten Views.

#### 1. Spielzeit, Sitzungen, Zuhause/Rettung, Durchschnitt und Median

Sitzungen zählen nur mit positiver Spielzeit. Zuerst je Installation und
`game_session_id` summieren, danach je Installation; **nicht** einzelne
Heartbeat-Längen mitteln. Diese Tabelle zeigt die beobachteten Werte über
die verfügbare Historie; laufende Sitzungen, Queue-Verluste und abgeschnittene
Aufbewahrungsränder können unvollständig sein. Ein Zeitfilter innerhalb der
Delta-Abfrage würde „Zeit innerhalb des Fensters“, nicht volle
Sitzungsdauer bedeuten und muss entsprechend beschriftet werden.

```sql
, sessions AS (
    SELECT
        installation_id,
        game_session_id,
        sum(seconds) AS total_seconds,
        sumIf(seconds, scene = 'home') AS home_seconds,
        sumIf(seconds, scene = 'rescue') AS rescue_seconds
    FROM e
    WHERE event_name = 'playtime' AND seconds > 0
      AND game_session_id IS NOT NULL AND game_session_id != ''
    GROUP BY installation_id, game_session_id
), installations AS (
    SELECT
        installation_id,
        sum(total_seconds) AS total_seconds,
        sum(home_seconds) AS home_seconds,
        sum(rescue_seconds) AS rescue_seconds
    FROM sessions
    GROUP BY installation_id
)
SELECT
    'Spielsitzung' AS einheit,
    count() AS anzahl,
    sum(total_seconds) / 3600 AS gesamt_stunden,
    sum(home_seconds) / 3600 AS zuhause_stunden,
    sum(rescue_seconds) / 3600 AS rettung_stunden,
    avg(total_seconds) / 60 AS durchschnitt_minuten,
    median(total_seconds) / 60 AS median_minuten_approx
FROM sessions
UNION ALL
SELECT
    'Installation', count(),
    sum(total_seconds) / 3600,
    sum(home_seconds) / 3600,
    sum(rescue_seconds) / 3600,
    avg(total_seconds) / 60,
    median(total_seconds) / 60
FROM installations
```

`median` ist PostHogs approximativer Median. Die beiden Zeilen sind
verschiedene Bezugsgrößen derselben Gesamtzeit und **nicht zu addieren**.
`play_session_started` kann separat diagnostiziert werden, ersetzt aber
nicht die Definition „Sitzung mit positiver Spielzeit“.

#### 2. DAU / WAU / MAU und Tagesverlauf

Gezählt werden aktive **Installationen** mit positivem `playtime`, nicht
Menübesuche oder automatische Vermittlungen. Die Kennzahlen verwenden die
letzten **1 / 7 / 30 vollständig abgeschlossenen UTC-Tage**; WAU/MAU sind
rollierende Fenster, keine Summe der DAU und keine Kalenderwoche/-monate.

```sql
SELECT
    uniqExactIf(installation_id,
        occurred_at >= toStartOfDay(now(), 'UTC') - INTERVAL 1 DAY) AS dau,
    uniqExactIf(installation_id,
        occurred_at >= toStartOfDay(now(), 'UTC') - INTERVAL 7 DAY) AS wau,
    uniqExact(installation_id) AS mau
FROM e
WHERE event_name = 'playtime' AND seconds > 0
  AND occurred_at >= toStartOfDay(now(), 'UTC') - INTERVAL 30 DAY
  AND occurred_at < toStartOfDay(now(), 'UTC')
```

Als separaten Insight mit demselben gemeinsamen Anfang speichern:

```sql
SELECT toDate(occurred_at) AS tag, uniqExact(installation_id) AS dau
FROM e
WHERE event_name = 'playtime' AND seconds > 0
  AND occurred_at >= toStartOfDay(now(), 'UTC') - INTERVAL 90 DAY
  AND occurred_at < toStartOfDay(now(), 'UTC')
GROUP BY tag
ORDER BY tag
```

Tage ohne Daten fehlen in dieser Ergebnistabelle; im Diagramm nicht als
unbekannte positive Aktivität interpolieren. Ein Zeitdelta wird seinem
originalen Ereigniszeitpunkt zugeordnet; ein Checkpoint nahe Mitternacht
kann einen kleinen über die Tagesgrenze reichenden Zeitanteil enthalten.

#### 3. D1/D7: Rückkehr nach erstmals beobachtetem eingewilligtem Spiel

Pro Installation wird der erste **verfügbare positive Spieltag** ermittelt,
nicht Installationsdatum, „Neues Spiel“ oder bloße Zustimmung. D1/D7 heißt
erneute positive Spielzeit genau am folgenden beziehungsweise siebten
Kalendertag. Noch nicht vollständig vergangene Rückkehrtage liefern `NULL`,
nicht fälschlich 0 %. Der 90-Tage-Anzeigefilter kommt erst **nach** der
Bestimmung des ersten Tages aus der gesamten verfügbaren Historie.

```sql
, days AS (
    SELECT installation_id, toDate(occurred_at) AS play_day
    FROM e
    WHERE event_name = 'playtime' AND seconds > 0
    GROUP BY installation_id, play_day
), first_days AS (
    SELECT installation_id, min(play_day) AS first_day
    FROM days
    GROUP BY installation_id
), returns AS (
    SELECT
        f.installation_id,
        f.first_day,
        max(if(dateDiff('day', f.first_day, d.play_day) = 1, 1, 0)) AS returned_d1,
        max(if(dateDiff('day', f.first_day, d.play_day) = 7, 1, 0)) AS returned_d7
    FROM first_days f
    JOIN days d ON d.installation_id = f.installation_id
    GROUP BY f.installation_id, f.first_day
)
SELECT
    first_day,
    count() AS erstmals_beobachtete_installationen,
    if(addDays(first_day, 1) < toDate(now()),
        100.0 * sum(returned_d1) / count(), NULL) AS d1_prozent,
    if(addDays(first_day, 7) < toDate(now()),
        100.0 * sum(returned_d7) / count(), NULL) AS d7_prozent
FROM returns
WHERE first_day >= toDate(now()) - INTERVAL 90 DAY
GROUP BY first_day
ORDER BY first_day
```

Späte Offline-Uploads können vergangene Tage und sogar den ersten
beobachteten Tag korrigieren. Ergebnisse der letzten sieben Tage sind
daher vorläufig. Abgelaufene Anbieterhistorie kann alte Installationen
erneut „erstmals“ erscheinen lassen: keine Lifetime-Retention oder echte
Neuinstallationen behaupten. Die Vergleichsgruppen werden aus Ereignissen
berechnet, **nicht** als gespeicherte Personenkohorten angelegt.

#### 4. Zeitlich geordnete Fortschrittskette

Eine Kette pro Installation, beginnend beim **ersten verfügbaren**
`game_started(kind='new')`: Outdoor-Pickup → echte Rettung → Vermittlung →
erfolgreicher Upgrade-/Einrichtungskauf. Alle Schritte müssen in den sieben
Tagen nach diesem Start und strikt nacheinander liegen. Nur Starts mit
abgelaufenem 7-Tage-Fenster werden angezeigt; die zusätzliche siebentägige
Offline-Nachlieferfrist macht jüngere Ergebnisse weiterhin vorläufig.

```sql
, first_new AS (
    SELECT installation_id, min(occurred_at) AS started_at
    FROM e
    WHERE event_name = 'game_started' AND kind = 'new'
    GROUP BY installation_id
), starts AS (
    SELECT installation_id, started_at
    FROM first_new
    WHERE started_at >= now() - INTERVAL 90 DAY
      AND started_at < now() - INTERVAL 7 DAY
), pickups AS (
    SELECT s.installation_id, s.started_at, min(e.occurred_at) AS picked_at
    FROM starts s
    JOIN e ON e.installation_id = s.installation_id
    WHERE e.event_name = 'cat_picked_up' AND e.pickup_location = 'outdoor'
      AND e.occurred_at > s.started_at
      AND e.occurred_at < s.started_at + INTERVAL 7 DAY
    GROUP BY s.installation_id, s.started_at
), rescues AS (
    SELECT p.installation_id, p.started_at, min(e.occurred_at) AS rescued_at
    FROM pickups p
    JOIN e ON e.installation_id = p.installation_id
    WHERE e.event_name = 'cat_rescued'
      AND e.occurred_at > p.picked_at
      AND e.occurred_at < p.started_at + INTERVAL 7 DAY
    GROUP BY p.installation_id, p.started_at
), adoptions AS (
    SELECT r.installation_id, r.started_at, min(e.occurred_at) AS adopted_at
    FROM rescues r
    JOIN e ON e.installation_id = r.installation_id
    WHERE e.event_name = 'cat_adopted'
      AND e.occurred_at > r.rescued_at
      AND e.occurred_at < r.started_at + INTERVAL 7 DAY
    GROUP BY r.installation_id, r.started_at
), purchases AS (
    SELECT a.installation_id, a.started_at, min(e.occurred_at) AS purchased_at
    FROM adoptions a
    JOIN e ON e.installation_id = a.installation_id
    WHERE e.event_name IN ('upgrade_purchased', 'home_item_purchased')
      AND e.occurred_at > a.adopted_at
      AND e.occurred_at < a.started_at + INTERVAL 7 DAY
    GROUP BY a.installation_id, a.started_at
)
SELECT 1 AS schritt, 'Neues Spiel' AS aktion, count() AS installationen FROM starts
UNION ALL
SELECT 2, 'Outdoor-Pickup', count() FROM pickups
UNION ALL
SELECT 3, 'Tatsaechliche Abgabe', count() FROM rescues
UNION ALL
SELECT 4, 'Vermittlung', count() FROM adoptions
UNION ALL
SELECT 5, 'Kauf nach Vermittlung', count() FROM purchases
ORDER BY schritt
```

Indoor-Pickups ersetzen niemals den Outdoor-Schritt. Ein Kauf **vor** der
Vermittlung zählt nicht als letzter Schritt dieser Kette. Gleiche
Zeitstempel beweisen keine Reihenfolge und werden konservativ nicht
erzwungen. Ohne Katzen-ID lässt sich **nicht** behaupten, alle Schritte
beträfen dieselbe Katze; dies ist eine geordnete Nutzungskette derselben
Installation, gegebenenfalls über mehrere Sitzungen hinweg.
Fortsetzen vorhandener Spielstände und wiederholte neue Spiele sind keine
neuen Installationen und nicht die Startgruppe dieses Insights.

Für eine reine Outdoor-Pickup → Rettung → Vermittlung-Kette unabhängig von
„Neues Spiel“ kann der erste `cat_picked_up` mit
`pickup_location='outdoor'` als Startanker dienen; den anschließenden
zusätzlichen Pickup-Schritt dann entfernen und dieselben geordneten
Abgabe-/Vermittlungsbedingungen beibehalten. Nicht bloß ungeordnete
Ereigniszahlen nebeneinander als Funnel ausgeben.

#### 5. Version/Plattform, Pickups, echte Rettungen und Spielmünzen

Version und Plattform kommen von jedem ursprünglichen Ereignis, nicht vom
Upload-Build. Gezählt wird hier die verfügbare Historie; bei Bedarf einen
klar beschrifteten Ereigniszeitfilter **nach** der Deduplizierung ergänzen.
Eine Installation kann über Updates in mehreren Versionszeilen stehen;
deren eindeutige Installationszahlen nicht zu einer Gesamtzahl addieren.

```sql
SELECT
    app_version, platform,
    uniqExactIf(installation_id, event_name = 'playtime' AND seconds > 0) AS aktive_installationen,
    sumIf(seconds, event_name = 'playtime' AND seconds > 0) / 3600 AS spielstunden,
    countIf(event_name = 'game_started' AND kind = 'new') AS neue_spiele,
    countIf(event_name = 'game_started' AND kind = 'continue') AS fortsetzungen,
    countIf(event_name = 'cat_picked_up' AND pickup_location = 'outdoor') AS outdoor_pickups,
    countIf(event_name = 'cat_picked_up' AND pickup_location = 'indoor') AS indoor_pickups,
    countIf(event_name = 'cat_rescued') AS gerettete_katzen,
    countIf(event_name = 'cat_adopted') AS vermittelte_katzen,
    sumIf(reward, event_name = 'cat_adopted') AS belohnung_muenzen
FROM e
GROUP BY app_version, platform
ORDER BY app_version, platform
```

Separater Kauf-Insight, ebenfalls mit dem gemeinsamen `WITH e AS (...)`:

```sql
SELECT
    app_version, platform, event_name,
    if(event_name = 'upgrade_purchased', upgrade_id, kind) AS kaufart,
    level AS upgrade_stufe,
    count() AS erfolgreiche_kaeufe,
    sum(price) AS ausgegebene_muenzen
FROM e
WHERE event_name IN ('upgrade_purchased', 'home_item_purchased')
GROUP BY app_version, platform, event_name, kaufart, upgrade_stufe
ORDER BY app_version, platform, event_name, kaufart, upgrade_stufe
```

`upgrade_stufe` ist bei Einrichtungskäufen leer. Nur erfolgreiche Käufe,
keine Grundausstattung, Preisvorschau oder bloßes Versetzen. Belohnungen
und Preise sind **Spielmünzen, kein Echtgeldumsatz**.

### Noch erforderliche Live-Abnahme

**Nicht als live verifiziert betrachten:** Es steht derzeit kein
eingerichtetes Betreiber-Test-/Produktionsprojekt zur Verfügung. Lokale
Fixtures und Fake-Transport-Tests ersetzen weder Aufnahme ins echte
Exportpaket noch PostHog-Ingestion und die Ausführung dieser Abfragen.
Die SQL-Bausteine verwenden dokumentierte HogQL-Funktionen; ihre
Serverausführung, Ergebnisse, Performance und Darstellung müssen im
konkreten Projekt geprüft werden. Dafür keine Produktionsprofile
einschalten und keine automatischen Testläufe gegen Ingestion richten.

Nach dem Betreiber-Setup bewusst einen exportierten Windows- und einen
signierten Android-Release-Build mit **Testprojekt-Token** prüfen:

1. Vor Zustimmung und nach Ablehnung keine ID/Queue/Requests; anschließend
   zustimmen und bekannte aktive Zeiten in Zuhause/Rettung spielen.
   Pause, Katalog, Hintergrund, AFK-Grenze, gehaltene Bewegung,
   Prozessneustart und 30-Minuten-Unterbrechung vergleichen.
2. Draußen aufheben, entkommen lassen, wieder aufheben, einmal abgeben;
   drinnen zweimal aufheben/absetzen. Erwartung: **zwei Outdoor-Pickups,
   zwei Indoor-Pickups, eine Rettung**. Mehrfachabgabe/Laden/Retry darf
   daraus keine weitere Rettung machen. Danach Vermittlung und bekannte
   Käufe einschließlich eines Kaufs vor der Vermittlung für den Funnel testen.
3. Offline spielen, wieder verbinden, Antwortverlust/Retry prüfen.
   Ereignis-IDs und ursprüngliche UTC-Zeiten müssen stabil bleiben.
   SQL-Summen/-Zähler dürfen durch Retry-Kopien nicht wachsen.
4. Die gespeicherten Ereignisse und sämtliche Insights gegen bekannte
   Sollwerte prüfen, nicht nur HTTP 200. Für D1/D7 kontrollierte synthetische
   Ereignisse im getrennten Testprojekt mit bekannten UTC-Tagen und
   stabilen IDs verwenden; keine realen Nutzer imitieren. Fehlende,
   verspätete und gleichzeitige Funnel-Schritte gezielt gegenprüfen.
5. Keine Personenprofile, gespeicherten IPs oder GeoIP-Eigenschaften;
   Kontakt/Löschverfahren, Widerruf während Versand und neue Kennung bei
   erneuter Zustimmung nachweisen. Bei geändertem Projekt-Token,
   Betreiberkontakt oder neuer Hinweisversion müssen alte lokale Kennung
   und Queue verschwinden und erneut Zustimmung erforderlich sein; keine
   alten Ereignisse an das neue Projekt senden. Exportierte Konfiguration, Android-
   `INTERNET`, Signatur und Debug-Sperre auf echten Geräten kontrollieren.

Erst mit dokumentierten Soll-/Ist-Ergebnissen dieses Durchlaufs und
geklärtem profilfreien Löschweg ist die **Live-Freigabe** abgeschlossen.

## Lizenzen

Der Code steht unter der Lizenz dieses Repositorys. Alle verwendeten Grafiken und
Töne sind **CC0** – Einzelheiten in [CREDITS.md](CREDITS.md).
