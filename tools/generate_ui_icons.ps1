<#
.SYNOPSIS
    Erzeugt den Symbol-Atlas fuer die Bedienoberflaeche.

.DESCRIPTION
    Schreibt `assets/sprites/ui_icons.png` -- eine Reihe aus 16x16 grossen
    Feldern. Die Reihenfolge muss zur Tabelle `ICONS` in
    `scripts/ui/icon_set.gd` passen; das Skript prueft das selbst und bricht
    bei einer Abweichung ab.

    Symbole sind standardmaessig ausgeschaltet. Erst die Einstellung
    `button_icons` ("text", "both" oder "icon") blendet sie ein.

.EXAMPLE
    pwsh tools/generate_ui_icons.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Root = Split-Path $PSScriptRoot -Parent
$Sprites = Join-Path $Root 'assets\sprites'
New-Item -ItemType Directory -Force -Path $Sprites | Out-Null

$Cell = 16

# Helle Symbole auf dem blaugrauen Knopfhintergrund des Themes.
$Light = '#fff0cb'
$Amber = '#e4b255'
$White = '#ffffff'
$Dark = '#2b2430'
$Red = '#e57689'
$Green = '#8fcf7f'
$Blue = '#a3e3ef'

function Box($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Color))
    try { $G.FillRectangle($brush, $X, $Y, $W, $H) } finally { $brush.Dispose() }
}

function Oval($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Color))
    try { $G.FillEllipse($brush, $X, $Y, $W, $H) } finally { $brush.Dispose() }
}

# Loescht wieder heraus -- fuer Ringe und Aussparungen. Farbe allein reicht
# nicht: der Atlas ist transparent, ein dunkles Rechteck bliebe sichtbar.
function Punch($G, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $mode = $G.CompositingMode
    $G.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)
    try { $G.FillRectangle($brush, $X, $Y, $W, $H) }
    finally { $brush.Dispose(); $G.CompositingMode = $mode }
}

function PunchOval($G, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $mode = $G.CompositingMode
    $G.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Transparent)
    try { $G.FillEllipse($brush, $X, $Y, $W, $H) }
    finally { $brush.Dispose(); $G.CompositingMode = $mode }
}

# Diagonale aus Einzelpunkten -- haelt die Kanten pixelig statt weichgezeichnet.
function Diagonal($G, [string]$Color, [int]$X, [int]$Y, [int]$Steps, [int]$StepX, [int]$StepY, [int]$Thickness = 2) {
    for ($i = 0; $i -lt $Steps; $i++) {
        Box $G $Color ($X + $i * $StepX) ($Y + $i * $StepY) $Thickness $Thickness
    }
}

# Winkel ">" -- vier Schritte hinunter, drei wieder hinauf.
function Chevron($G, [string]$Color, [int]$X, [int]$Y) {
    Diagonal $G $Color $X $Y 4 1 1
    Diagonal $G $Color ($X + 2) ($Y + 4) 3 -1 1
}

# Dreieck mit der Spitze oben. $Size ist die Hoehe, die Basis ist 2*$Size-1 breit.
function TriangleUp($G, [string]$Color, [int]$X, [int]$Y, [int]$Size) {
    for ($i = 0; $i -lt $Size; $i++) {
        Box $G $Color ($X + $Size - 1 - $i) ($Y + $i) (2 * $i + 1) 1
    }
}

# Dreieck mit der Spitze unten.
function TriangleDown($G, [string]$Color, [int]$X, [int]$Y, [int]$Size) {
    for ($i = 0; $i -lt $Size; $i++) {
        Box $G $Color ($X + $i) ($Y + $i) (2 * ($Size - $i) - 1) 1
    }
}

# Dreieck mit der Spitze rechts. $Size ist die Breite, die Basis 2*$Size-1 hoch.
function TriangleRight($G, [string]$Color, [int]$X, [int]$Y, [int]$Size) {
    for ($i = 0; $i -lt $Size; $i++) {
        Box $G $Color ($X + $i) ($Y + $i) 1 (2 * ($Size - $i) - 1)
    }
}

# Die Reihenfolge ist der Vertrag mit IconSet.ICONS.
$icons = @(
    @{ Name = 'furnish'; Draw = { param($G) # Sessel
            Box $G $Light 3 6 10 7; Box $G $Amber 4 8 8 4
            Box $G $Light 2 7 2 6; Box $G $Light 12 7 2 6
            Box $G $Light 4 13 2 2; Box $G $Light 10 13 2 2 } },
    @{ Name = 'supplies'; Draw = { param($G) # Paket
            Box $G $Amber 2 5 12 9; Box $G $Light 2 5 12 3
            Box $G $Dark 7 5 2 9 } },
    @{ Name = 'upgrade'; Draw = { param($G) # Pfeil nach oben
            TriangleUp $G $Light 2 2 6; Box $G $Light 6 8 4 6 } },
    @{ Name = 'pause'; Draw = { param($G)
            Box $G $Light 4 3 3 10; Box $G $Light 9 3 3 10 } },
    @{ Name = 'close'; Draw = { param($G)
            Diagonal $G $Light 4 4 8 1 1; Diagonal $G $Light 4 11 8 1 -1 } },
    @{ Name = 'resume'; Draw = { param($G) # Dreieck nach rechts
            TriangleRight $G $Light 4 2 6 } },
    @{ Name = 'menu'; Draw = { param($G)
            Box $G $Light 3 4 10 2; Box $G $Light 3 7 10 2; Box $G $Light 3 10 10 2 } },
    @{ Name = 'home'; Draw = { param($G) # Haus
            Diagonal $G $Light 2 8 7 1 -1; Diagonal $G $Light 14 8 7 -1 -1
            Box $G $Light 3 8 10 6; Box $G $Amber 6 10 4 4 } },
    @{ Name = 'cart'; Draw = { param($G) # Einkaufswagen
            Box $G $Light 2 3 3 2; Box $G $Light 4 5 2 6
            Box $G $Light 5 5 9 2; Box $G $Amber 6 7 7 3
            Oval $G $Light 5 11 3 3; Oval $G $Light 10 11 3 3 } },
    @{ Name = 'emergency'; Draw = { param($G) # Ausrufezeichen
            Oval $G $Red 1 1 14 14; Box $G $White 7 4 2 6; Box $G $White 7 11 2 2 } },
    @{ Name = 'rotate'; Draw = { param($G) # Kreispfeil
            Oval $G $Light 2 2 12 12; PunchOval $G 5 5 6 6
            Punch $G 8 0 8 7; TriangleUp $G $Light 8 1 4 } },
    @{ Name = 'store'; Draw = { param($G) # Kiste mit Pfeil hinein
            Box $G $Light 6 1 4 4; TriangleDown $G $Light 4 5 4
            Box $G $Amber 2 10 12 4; Box $G $Light 2 10 12 1 } },
    @{ Name = 'action'; Draw = { param($G)
            Oval $G $Light 2 2 12 12; Oval $G $Amber 5 5 6 6 } },
    @{ Name = 'sprint'; Draw = { param($G) # Doppelter Winkel
            Chevron $G $Light 2 4; Chevron $G $Light 8 4 } },
    @{ Name = 'play'; Draw = { param($G)
            TriangleRight $G $Green 4 2 6 } },
    @{ Name = 'new'; Draw = { param($G) # Plus
            Box $G $Light 6 2 4 12; Box $G $Light 2 6 12 4 } },
    @{ Name = 'options'; Draw = { param($G) # Schieberegler
            Box $G $Light 1 3 14 2; Box $G $Amber 4 1 3 6
            Box $G $Light 1 7 14 2; Box $G $Amber 10 5 3 6
            Box $G $Light 1 11 14 2; Box $G $Amber 6 9 3 6 } },
    @{ Name = 'quit'; Draw = { param($G) # Ein/Aus
            Oval $G $Light 3 3 10 10; PunchOval $G 5 5 6 6
            Punch $G 6 0 4 7; Box $G $Light 7 1 2 7 } },
    @{ Name = 'credits'; Draw = { param($G) # Herz
            Oval $G $Red 2 3 7 7; Oval $G $Red 7 3 7 7
            Box $G $Red 3 6 10 3; TriangleDown $G $Red 3 8 6 } },
    @{ Name = 'accept'; Draw = { param($G) # Haken
            Diagonal $G $Green 3 8 4 1 1; Diagonal $G $Green 6 11 7 1 -1 } },
    @{ Name = 'decline'; Draw = { param($G)
            Diagonal $G $Red 4 4 8 1 1; Diagonal $G $Red 4 11 8 1 -1 } },
    @{ Name = 'info'; Draw = { param($G)
            Oval $G $Blue 1 1 14 14; Box $G $Dark 7 3 2 2; Box $G $Dark 7 6 2 7 } },
    @{ Name = 'coins'; Draw = { param($G) # Gestapelte Muenzen
            Oval $G $Amber 1 8 14 6; Oval $G $Light 5 10 6 2
            Oval $G $Amber 1 4 14 6; Oval $G $Light 5 6 6 2 } },
    @{ Name = 'food'; Draw = { param($G) # Napf mit Futter
            Box $G $Amber 3 5 10 3; Box $G $Amber 5 3 6 3
            Oval $G $Light 1 6 14 8; Oval $G $Amber 4 8 8 3 } },
    @{ Name = 'water'; Draw = { param($G) # Napf mit Wasser
            Oval $G $Blue 3 4 10 5
            Oval $G $Light 1 6 14 8; Oval $G $Blue 4 8 8 3 } },
    @{ Name = 'wash'; Draw = { param($G) # Tropfen
            TriangleUp $G $Blue 3 1 5; Oval $G $Blue 3 5 10 10
            Box $G $White 5 8 2 3 } },
    @{ Name = 'vet'; Draw = { param($G) # Kreuz
            Box $G $White 6 2 4 12; Box $G $White 2 6 12 4
            Box $G $Red 7 3 2 10; Box $G $Red 3 7 10 2 } },
    @{ Name = 'toy'; Draw = { param($G) # Ball
            Oval $G $Light 2 2 12 12; Box $G $Red 2 7 12 2; Box $G $Red 7 2 2 12 } },
    @{ Name = 'litter'; Draw = { param($G) # Wanne mit Streu
            Box $G $Light 1 6 14 8; Box $G $Amber 3 8 10 4
            Box $G $Light 4 9 2 1; Box $G $Light 9 10 2 1 } },
    @{ Name = 'pantry'; Draw = { param($G) # Schrank
            Box $G $Light 2 1 12 14; Box $G $Amber 3 2 4 5
            Box $G $Amber 9 2 4 5; Box $G $Amber 3 9 10 5
            Box $G $Dark 7 3 2 2 } },
    @{ Name = 'faucet'; Draw = { param($G) # Wasserhahn
            Box $G $Light 1 2 4 9; Box $G $Light 1 2 10 3
            Box $G $Light 8 4 3 4; Box $G $Blue 9 9 2 3
            Oval $G $Blue 8 11 4 4 } }
)

# Vertrag mit IconSet.ICONS pruefen, damit Atlas und Tabelle nie auseinanderlaufen.
$setPath = Join-Path $Root 'scripts\ui\icon_set.gd'
$expected = @()
$inTable = $false
foreach ($line in (Get-Content -LiteralPath $setPath)) {
    if ($line -match '^const ICONS :=') { $inTable = $true; continue }
    if ($inTable) {
        if ($line -match '^\}') { break }
        if ($line -match '^\s*"([a-z_]+)"\s*:\s*(\d+),') { $expected += $Matches[1] }
    }
}
$actual = $icons | ForEach-Object { $_.Name }
if (Compare-Object $expected $actual -SyncWindow 0) {
    Write-Host 'Atlas und IconSet.ICONS stimmen nicht ueberein.' -ForegroundColor Red
    Write-Host "  IconSet: $($expected -join ', ')"
    Write-Host "  Skript : $($actual -join ', ')"
    exit 1
}

$width = $icons.Count * $Cell
$bitmap = [System.Drawing.Bitmap]::new($width, $Cell, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.Clear([System.Drawing.Color]::Transparent)
    for ($index = 0; $index -lt $icons.Count; $index++) {
        # Jedes Symbol zeichnet in lokalen Koordinaten 0..15; die Verschiebung
        # macht der Grafikkontext.
        $state = $graphics.Save()
        $graphics.TranslateTransform($index * $Cell, 0)
        $graphics.SetClip([System.Drawing.Rectangle]::new(0, 0, $Cell, $Cell))
        & $icons[$index].Draw $graphics
        $graphics.Restore($state)
    }
}
finally {
    $graphics.Dispose()
}

$target = Join-Path $Sprites 'ui_icons.png'
$bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

Write-Host "Erzeugt: ui_icons.png ($width x $Cell, $($icons.Count) Symbole)" -ForegroundColor Green
