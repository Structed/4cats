# 4cats

Ein 2D-Spiel aus der Vogelperspektive: Du suchst streunende Katzen, trägst sie
nach Hause und pflegst sie dort gesund, bis sie ein neues Zuhause finden.

Läuft auf **Windows** und **Android** (Handy und Tablet), vollständig mit **Touch**
oder mit Tastatur bedienbar.

| Rettung | Zuhause |
|---|---|
| Streuner suchen, vorsichtig annähern, aufheben | Haus einrichten, Näpfe füllen, Katzen pflegen, Katzenklo reinigen |

## Spielablauf

1. **Rausgehen**: Ein prozedural erzeugtes Viertel mit Straßen, Häusern und Bäumen.
2. **Katzen finden**: Geh in normalem Tempo hin und warte einen Moment – über
   der Katze füllt sich ein Vertrauensbalken. Ist er voll, kannst du sie
   aufheben. Nur **Rennen** (`Shift`) verschreckt Katzen; eine aufgeschreckte
   Katze läuft kurz weg, beruhigt sich aber wieder und behält einen Teil ihres
   Vertrauens. Fliehen ist langsamer als Gehen, du holst sie also immer ein.
3. **Gefahren**: Autos fahren die Straßen entlang, Hunde streunen herum. Wer
   erschrickt, verliert eine getragene Katze – sie läuft weg, mehr passiert nicht.
   Es gibt **kein Zeitlimit** und man kann nicht verlieren.
4. **Heimbringen**: Betritt die grün markierte Heimzone.
5. **Pflegen**: Zu Hause laufen die Katzen frei herum. Du bewegst dich mit der
   Spielfigur durch das Haus, füllst Futter und Wasser nach und reinigst das
   Katzenklo. Katzen fressen, trinken, spielen und benutzen das Klo selbst.
   Zum Waschen oder Behandeln nimmst du eine Katze auf und trägst sie zur
   passenden Station. Symbole und Animationen zeigen, was sie braucht –
   keine Pflegekarten oder Fortschrittsbalken.
6. **Vermitteln**: Bleiben Hunger, Durst, Sauberkeit, Gesundheit und
   **Beschäftigung** mindestens bei 80, wird die Katze nach kurzer Zeit
   adoptiert und bringt Münzen.
7. **Einrichten und ausbauen**: Näpfe, Waschplatz, Behandlungsstation, Spielzeug
   und Katzenklo sind frei auf einem Raster platzierbar. Eine Grundausstattung
   ist kostenlos; zusätzliche Einrichtung und die bisherigen Upgrades
   (Tragekorb, Leckerlis, Komfort, Tierarzt) kosten Münzen.

### Leben im Katzenhaus

**Versorgung kostet keine Münzen:** Futter und Wasser nachfüllen, waschen,
behandeln und frische Streu bereitstellen sind jederzeit kostenlos. Vorräte
in Näpfen sind endlich; Katzen brauchen tatsächlich erreichbare, gefüllte
Näpfe und ausgelegtes Spielzeug. Ein volles Katzenklo wird gemieden und
beeinträchtigt die Sauberkeit der betroffenen Katzen.

Die Versorgung läuft auch weiter, wenn du draußen Katzen rettest. Pause,
geöffnete Kataloge, Hauptmenü und geschlossene App halten sie an; es gibt
keine nachträgliche Offline-Simulation. Gesundheit verbessert sich durch
Behandlung, nicht automatisch. Es gibt weiterhin keinen Katzentod.

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

Spielstände behalten Einrichtung, Inventar, Vorräte, Verschmutzung und
Katzenbedürfnisse. Ältere Spielstände erhalten einmalig die Grundausstattung
und ein erfülltes Beschäftigungsbedürfnis; Katzen, Münzen und Upgrades bleiben
erhalten.

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
  autoload/              GameState, SaveManager, AudioManager, SceneRouter
  data/                  Katzen, Hauszustand und Einrichtungskatalog
  rescue/                Spieler, Katzen-Verhalten, Level-Erzeugung, Gefahren
  home/                  Haus-Simulation, Wegfindung, Einrichtung, Pflege und HUD
  ui/                    Menü, HUD, virtueller Joystick
  dev/                   Entwicklungshilfen (nicht Teil des Spiels)
resources/               TileSet und UI-Design
assets/                  Grafik und Ton (siehe CREDITS.md)
tools/                   Skripte zum Bauen, Prüfen und Erzeugen von Assets
.github/
  github-app.yml         Projekteinstellungen für die GitHub-Copilot-App
  actions/setup-godot/   Godot samt Export-Vorlagen in CI installieren
  workflows/ci.yml       Prüfen und Bauen bei jedem Push
  workflows/android.yml  APK bauen, sobald ein Pull Request gemergt wurde
```

### Technische Eckdaten

- **Godot 4.7.2**, GDScript
- Renderer `gl_compatibility` (OpenGL ES 3.0) – größte Abdeckung auf Android
- Basisauflösung 640 × 360, Streckmodus `canvas_items` mit `expand`, damit
  breite Handy-Displays mehr Sichtfeld statt schwarzer Balken bekommen
- Texturfilter `Nearest` (Pixel-Art)
- Android-Paketname `de.structed.fourcats`, Ausrichtung `sensor_landscape`,
  **keine** Berechtigungen
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
# Spiel starten
pwsh tools/godot.ps1 --path .

# Direkt in eine Szene springen
pwsh tools/godot.ps1 --path . -- --start=rescue
pwsh tools/godot.ps1 --path . -- --start=home --demo

# Projektkonfiguration prüfen (Eingaben, Autoloads, Szenen)
pwsh tools/godot.ps1 --headless --path . --script res://tools/check_project.gd

# Spiellogik testen (Retten, Pflegen, Vermitteln, Speichern, Levelaufbau)
pwsh tools/godot.ps1 --headless --path . -- --test

# Spieltest: Katze einfangen und zu Hause mit echter Steuerung versorgen
pwsh tools/godot.ps1 --headless --path . -- --playtest

# Durchlauf: alle Szenen und Knoepfe einmal anfassen
pwsh tools/godot.ps1 --headless --path . -- --smoketest

# Alle Skripte auf Übersetzungsfehler prüfen
pwsh tools/lint_scripts.ps1

# Übersichtsbild eines erzeugten Viertels
pwsh tools/godot.ps1 --headless --path . --script res://tools/preview_level.gd -- --out=level.png

# Bildschirmfoto einer Szene
pwsh tools/screenshot.ps1 -Scene home -OutputPath shot.png -Demo

# Touch-Platzierung oder Einrichtungskatalog ansehen
pwsh tools/screenshot.ps1 -Scene home -OutputPath placement.png -Demo -Touch -HomeView placement
pwsh tools/screenshot.ps1 -Scene home -OutputPath catalog.png -Demo -HomeView furnish
```

Die Prüfungen geben bei Fehlern Exit-Code 1 zurück und laufen so auch in CI.
Spiel-, Durchlauf- und Logiktests benutzen getrennte temporäre Spielstände
und Einstellungen; auch `--demo` überschreibt keinen normalen Spielstand.

Die fünf Prüfungen decken unterschiedliche Fehlerklassen ab:

| Prüfung | Findet |
|---|---|
| `lint_scripts.ps1` | Übersetzungsfehler in **jedem** Skript – auch in Dateien, die im Spiel selten geladen werden |
| `check_project.gd` | Fehlende Eingaben, Autoloads, Szenen; falscher Renderer |
| `--test` | Regeln: Tragen, Hausversorgung, Einrichtung, Vermittlung, Migration, Speichern, Tempo-Verhältnisse |
| `--playtest` | Katze mit echter Physik fangen und über räumliche Pflege zu Hause vermitteln |
| `--smoketest` | Laufzeitfehler in Szenen, Kontextaktionen, Touch-Bedienung, Einrichtung und Menüs |

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

```powershell
# Windows
mkdir build/windows
pwsh tools/godot.ps1 --headless --path . --export-release "Windows Desktop" build/windows/4cats.exe

# Android (Testfassung, nutzt den Debug-Keystore)
mkdir build/android
pwsh tools/godot.ps1 --headless --path . --export-debug "Android" build/android/4cats.apk
```

Für eine **veröffentlichbare** Android-Fassung braucht es einen eigenen
Release-Keystore. Er gehört **nicht** ins Repository:

```powershell
keytool -v -genkey -keystore 4cats.keystore -alias fourcats -keyalg RSA -validity 10000

$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH     = "C:\pfad\zu\4cats.keystore"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER     = "fourcats"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "<passwort>"

pwsh tools/godot.ps1 --headless --path . --export-release "Android" build/android/4cats.apk
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
| Jeder Push und jeder Pull Request | `ci.yml` | Alle Prüfungen, dazu die Windows-Fassung als Artefakt `4cats-windows` |
| Sobald ein Pull Request **gemergt** wird | `android.yml` | APK als Artefakt `4cats-android-pr<Nummer>` |

Das APK liegt im jeweiligen Lauf unter **Actions → Android → Artifacts** und ist
mit einem in der Aktion erzeugten **Debug-Keystore** signiert: installierbar zum
Ausprobieren, aber nicht zur Veröffentlichung geeignet. Dafür bleibt es beim
eigenen Release-Keystore aus dem Abschnitt oben – dessen Passwörter haben in
einem öffentlichen Build nichts zu suchen.

Beide Workflows holen Godot über dieselbe Aktion `.github/actions/setup-godot`.
Eine neue Godot-Version wird deshalb nur in `GODOT_VERSION` der beiden Workflows
geändert, nicht in der Installationslogik.

### GitHub-Copilot-App

`.github/github-app.yml` hinterlegt projektbezogene Hinweise und macht die
Befehle oben als Knöpfe verfügbar – Tests, Konfigurationsprüfung, Level-
Übersicht, Windows-Build und das direkte Anspringen einzelner Szenen. Beim
Anlegen einer Sitzung werden die Ressourcen einmal importiert, weil `.godot/`
nicht eingecheckt ist.

Die App wendet die Datei erst an, nachdem man sie einmal geprüft und bestätigt
hat; das gilt nach jeder Änderung erneut.

## Lizenzen

Der Code steht unter der Lizenz dieses Repositorys. Alle verwendeten Grafiken und
Töne sind **CC0** – Einzelheiten in [CREDITS.md](CREDITS.md).
