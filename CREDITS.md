# Credits

Alle externen Assets in diesem Projekt stehen unter **CC0 1.0 Universal**
(Public Domain Dedication). Eine Namensnennung ist damit nicht verpflichtend –
wir tun es trotzdem, weil die Arbeit es verdient.

## Grafik

### Kenney – RPG Urban Pack (CC0)

- Quelle: <https://kenney.nl/assets/rpg-urban-pack>
- Verwendet als: `assets/kenney/urban_tilemap.png`
- Enthält: Straßen, Bürgersteige, Gras, Hausfassaden, Bäume, Autos und die
  Spielfiguren
- Lizenztext: `assets/kenney/rpg-urban-pack.license.txt`

## Ton

### Kenney – Interface Sounds (CC0)

- Quelle: <https://kenney.nl/assets/interface-sounds>
- Verwendet als: `assets/audio/ui_click.ogg`, `ui_back.ogg`, `pickup.ogg`,
  `deliver.ogg`, `care.ogg`, `adopt.ogg`, `coins.ogg`, `meow.ogg`
- Lizenztext: `assets/audio/interface-sounds.license.txt`

> `meow.ogg` ist derzeit ein Platzhalter aus diesem Paket. Sobald ein echtes
> Miauen unter CC0 vorliegt, kann die Datei einfach ersetzt werden – der
> Dateiname bleibt gleich.

### Kenney – Impact Sounds (CC0)

- Quelle: <https://kenney.nl/assets/impact-sounds>
- Verwendet als: `assets/audio/scare.ogg`
- Lizenztext: `assets/audio/impact-sounds.license.txt`

## Eigene Grafik

Die folgenden Dateien sind in diesem Projekt entstanden und werden aus Skripten
erzeugt, damit sie reproduzierbar bleiben:

| Datei | Erzeugt von | Beschreibung |
|---|---|---|
| `assets/sprites/cats.png` | `tools/generate_cat_sprites.ps1` | Katzen-Spritesheet, 4 Fellfarben × 4 Richtungen × 2 Bilder |
| `assets/icon/icon.svg` | von Hand | Spielsymbol |
| `assets/icon/icon_192.png` | `tools/generate_icons.ps1` | Android-Launcher-Symbol |
| `assets/icon/icon_adaptive_*_432.png` | `tools/generate_icons.ps1` | Adaptive Android-Symbole |
| `resources/urban_tileset.tres` | `tools/generate_tileset.ps1` | TileSet aus dem RPG Urban Pack |
| `assets/sprites/home_items.png` | `tools/generate_home_assets.ps1` | Sechs Katzenhaus-Gegenstände mit leeren, gefüllten, benutzten und verschmutzten Zuständen |
| `assets/sprites/home_tiles.png` | `tools/generate_home_assets.ps1` | Holzboden, Wand und Ausgang des Katzenhauses |
| `assets/sprites/home_icons.png` | `tools/generate_home_assets.ps1` | Bedarfssymbole für die Gedankenblasen der Katzen |
| `resources/home_tileset.tres` | `tools/generate_home_assets.ps1` | TileSet aus den selbst erzeugten Hausgrafiken |

Kenney hat kein Paket mit Katzen aus der Vogelperspektive, deshalb wurden die
Katzen für dieses Projekt gezeichnet – bewusst im 16 × 16-Stil des Urban Packs,
damit sie sich nahtlos einfügen.

Die originalen Hausgrafiken sind ebenfalls in diesem Projekt entstanden und
stehen unter **CC0 1.0 Universal**. Sie sind keine übernommenen Kenney-Grafiken.

## Engine

[Godot Engine](https://godotengine.org) 4.7.2, MIT-Lizenz.
