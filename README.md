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
4. **Heimbringen**: Ein grüner Pfeil zeigt dir während der gesamten Rettung den
   Weg nach Hause – am Bildschirmrand oder direkt an der Heimzone, wenn sie im
   Bild ist. Betritt die grün markierte Heimzone, um Katzen abzugeben.
5. **Pflegen**: Zu Hause laufen die Katzen frei herum. Du bewegst dich mit der
   Spielfigur durch das Haus, füllst Futter und Wasser nach und reinigst das
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
   Zustandsanzeige alle fünf Werte, fehlende Voraussetzungen, den
   Genesungsfortschritt und die verbleibende Zeit an.
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
  workflows/android.yml  Signiertes APK und Release nach PR-Merge in main
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
# Nach einem frischen Checkout zuerst Ressourcen und Projektklassen importieren
pwsh tools/godot.ps1 --headless --path . --import

# Spiel starten
pwsh tools/godot.ps1 --path .

# Direkt in eine Szene springen
pwsh tools/godot.ps1 --path . -- --start=rescue
pwsh tools/godot.ps1 --path . -- --start=home --demo

# Projektkonfiguration prüfen (Eingaben, Autoloads, Szenen, Versionen)
pwsh tools/godot.ps1 --headless --path . --script res://tools/check_project.gd

# Spiellogik testen (Retten, Pflegen, Vermitteln, Speichern, Levelaufbau)
pwsh tools/godot.ps1 --headless --path . -- --test

# Spieltest: Katze einfangen und zu Hause mit echter Steuerung versorgen
pwsh tools/godot.ps1 --headless --path . -- --playtest

# Durchlauf: alle Szenen und Knoepfe einmal anfassen
pwsh tools/godot.ps1 --headless --path . -- --smoketest

# Alle Skripte auf Übersetzungsfehler prüfen
pwsh tools/lint_scripts.ps1

# Automatische Versionsberechnung und APK-Metadaten prüfen
pwsh tools/test_versioning.ps1

# Übersichtsbild eines erzeugten Viertels
pwsh tools/godot.ps1 --headless --path . --script res://tools/preview_level.gd -- --out=level.png

# Bildschirmfoto einer Szene
pwsh tools/screenshot.ps1 -Scene home -OutputPath shot.png -Demo

# Touch-Platzierung oder Einrichtungskatalog ansehen
pwsh tools/screenshot.ps1 -Scene home -OutputPath placement.png -Demo -Touch -HomeView placement
pwsh tools/screenshot.ps1 -Scene home -OutputPath catalog.png -Demo -HomeView furnish

# Vermittlungsstatus einer getragenen Katze mit Touch-Bedienung ansehen
pwsh tools\screenshot.ps1 -Scene home -OutputPath cat.png -Demo -Touch -HomeView cat
```

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

**In Obtainium einrichten:**

1. `https://github.com/Structed/4cats` als App-Quelle hinzufügen.
2. Als Sortiermethode **„Name“** wählen. Das sortiert die vollständigen Tags
   natürlich, also `0.1.10` nach `0.1.9`, und die alten `android-pr-*`-Tags
   vor den neuen numerischen Tags. **Nicht „Intelligenter Name“** verwenden:
   Bei gemischten Formaten kann diese Methode die alte PR-Nummer als höhere
   Version werten. Auch die Datumssortierung ist ungeeignet, weil ein älterer
   Merge bei parallelen Builds erst nach einem neueren veröffentlicht werden kann.
   Die Bevorzugung des GitHub-„Latest“-Releases ausschalten, damit die
   Versionssortierung maßgeblich bleibt.
3. `4cats.apk` verwenden und den **Release-Tag als Version** beibehalten.
   Prereleases, „nur verfolgen“ und ein Veröffentlichungsdatum als
   Versionsersatz sind nicht nötig.

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

## Lizenzen

Der Code steht unter der Lizenz dieses Repositorys. Alle verwendeten Grafiken und
Töne sind **CC0** – Einzelheiten in [CREDITS.md](CREDITS.md).
