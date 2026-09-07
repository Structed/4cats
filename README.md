# 4cats

Ein 2D-Spiel aus der Vogelperspektive: Du suchst streunende Katzen, trägst sie
nach Hause und pflegst sie dort gesund, bis sie ein neues Zuhause finden.

Läuft auf **Windows** und **Android** (Handy und Tablet), vollständig mit **Touch**
oder mit Tastatur bedienbar.

| Rettung | Zuhause |
|---|---|
| Streuner suchen, vorsichtig annähern, aufheben | Füttern, tränken, waschen, verarzten |

## Spielablauf

1. **Rausgehen**: Ein prozedural erzeugtes Viertel mit Straßen, Häusern und Bäumen.
2. **Katzen finden**: Nähere dich *langsam* – wer rennt, verschreckt die Katze.
   Über der Katze füllt sich ein Vertrauensbalken; ist er voll, kannst du sie aufheben.
3. **Gefahren**: Autos fahren die Straßen entlang, Hunde streunen herum. Wer
   erschrickt, verliert eine getragene Katze – sie läuft weg, mehr passiert nicht.
   Es gibt **kein Zeitlimit** und man kann nicht verlieren.
4. **Heimbringen**: Betritt die grün markierte Heimzone.
5. **Pflegen**: Jede Katze hat vier Werte – Hunger, Durst, Sauberkeit, Gesundheit.
   Per Tippen füllst du sie auf. Jede Aktion hat eine kurze Abklingzeit.
6. **Vermitteln**: Bleiben alle vier Werte über 80, wird die Katze nach kurzer Zeit
   adoptiert und bringt Münzen.
7. **Ausbauen**: Münzen fließen in Tragekorb, Leckerlis, Komfort und Tierarzt.

## Steuerung

| Aktion | PC | Touch |
|---|---|---|
| Bewegen | `WASD` / Pfeiltasten | Virtueller Joystick links (erscheint unter dem Daumen) |
| Katze aufheben | `E` oder `Leertaste` | Knopf rechts unten |
| Pause | `Esc` | – |
| Menüs | Maus | Tippen |

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
  home/                  Zuhause und Pflegekarten
scripts/
  autoload/              GameState, SaveManager, AudioManager, SceneRouter
  data/                  CatData (Beschreibung einer Katze)
  rescue/                Spieler, Katzen-Verhalten, Level-Erzeugung, Gefahren
  home/                  Pflege-Oberfläche
  ui/                    Menü, HUD, virtueller Joystick
  dev/                   Entwicklungshilfen (nicht Teil des Spiels)
resources/               TileSet und UI-Design
assets/                  Grafik und Ton (siehe CREDITS.md)
tools/                   Skripte zum Bauen, Prüfen und Erzeugen von Assets
.github/
  github-app.yml         Projekteinstellungen für die GitHub-Copilot-App
  workflows/ci.yml       Prüfen und Bauen bei jedem Push
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

# Übersichtsbild eines erzeugten Viertels
pwsh tools/godot.ps1 --headless --path . --script res://tools/preview_level.gd -- --out=level.png

# Bildschirmfoto einer Szene
pwsh tools/screenshot.ps1 -Scene home -OutputPath shot.png -Demo
```

Beide Prüfungen geben bei Fehlern Exit-Code 1 zurück und laufen so auch in CI.

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
