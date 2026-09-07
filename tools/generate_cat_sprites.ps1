<#
.SYNOPSIS
    Erzeugt das Katzen-Spritesheet fuer 4cats.

.DESCRIPTION
    Kenney hat kein Top-Down-Katzenpaket, deshalb werden die Katzen hier
    aus Pixel-Karten erzeugt. Das haelt sie stilistisch beim 16x16-Look des
    RPG Urban Packs und macht Farbvarianten trivial.

    Ausgabe:
      assets/sprites/cats.png          Spritesheet, 8 Spalten x 4 Zeilen a 16 px
      (optional) ein vergroesserter Preview zum Anschauen

    Spaltenreihenfolge: unten, oben, links, rechts -- je Idle- und Laufframe.
    Zeilen: die vier Fellvarianten.

.PARAMETER PreviewPath
    Wenn gesetzt, wird zusaetzlich eine 8-fach vergroesserte Vorschau gespeichert.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\assets\sprites\cats.png"),
    [string]$PreviewPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$TILE = 16

# Zeichen -> Palettenrolle
#   .  transparent      o  Umriss          b  Fell (Grundton)
#   d  Fell dunkel      l  Fell hell       e  Auge
#   p  rosa (Nase/Ohr)  w  weiss

# Ansicht von unten (Katze schaut zum Spieler). Nur die linke Haelfte,
# die rechte wird gespiegelt -- so bleibt das Sprite garantiert symmetrisch.
$CAT_DOWN_HALF = @(
    '........'
    '..oo....'
    '.obbo...'
    '.opbo...'
    '.opbbooo'
    '..obbbbb'
    '..obbbbb'
    '..obebbb'
    '..obbbbb'
    '..obbbll'
    '..obbblp'
    '..oobbbb'
    '...obbbb'
    '...obbbb'
    '...ollbb'
    '...ooooo'
)

# Ansicht von oben (Katze laeuft vom Spieler weg): keine Augen, dafuer
# eine dunklere Ruecken-Zeichnung.
$CAT_UP_HALF = @(
    '........'
    '..oo....'
    '.obbo...'
    '.obbo...'
    '.obbbooo'
    '..obbbbb'
    '..obbbbb'
    '..obbbbb'
    '..obdbbb'
    '..obbdbb'
    '..obbdbb'
    '..oobbbb'
    '...obbbb'
    '...obbbb'
    '...ollbb'
    '...ooooo'
)

# Seitenansicht nach links, volle Breite. Rechts wird daraus gespiegelt.
$CAT_LEFT = @(
    '................'
    '..oo............'
    '..obo...........'
    '.oobbooo.....oo.'
    '.obbbbbbo....obo'
    'obebbbbbbo...obo'
    'opbbbbbbbbbboobo'
    '.obbbbbbbbbbbobo'
    '.obbbbbbbbbbbbbo'
    '.oobbbbbbbbbbbo.'
    '..obbbbbbbbbbbo.'
    '..obbbbbbbbbbo..'
    '..obbbbbbbbbbo..'
    '..oolboooolbo...'
    '....oo....oo....'
    '................'
)

# Fellvarianten. Der Umriss wird aus dem Grundton abgeleitet.
$VARIANTS = @(
    @{ Name = 'orange'; Base = '#F0A868'; Dark = '#D4834A'; Light = '#FFDCA8' }
    @{ Name = 'grau';   Base = '#9AA5B1'; Dark = '#6B7683'; Light = '#DCE3EA' }
    @{ Name = 'schwarz';Base = '#5A535F'; Dark = '#3A353F'; Light = '#8A8090' }
    @{ Name = 'creme';  Base = '#F2E7D5'; Dark = '#CFBFA4'; Light = '#FFFFFF' }
)

$EYE_COLOR = '#2B2B33'
$PINK_COLOR = '#E08F9C'
$WHITE_COLOR = '#FFFFFF'


function ConvertFrom-Hex {
    param([string]$Hex)
    $h = $Hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(255,
        [Convert]::ToInt32($h.Substring(0, 2), 16),
        [Convert]::ToInt32($h.Substring(2, 2), 16),
        [Convert]::ToInt32($h.Substring(4, 2), 16))
}

function Get-Darkened {
    param([System.Drawing.Color]$Color, [double]$Factor = 0.45)
    return [System.Drawing.Color]::FromArgb(255,
        [int][Math]::Round($Color.R * $Factor),
        [int][Math]::Round($Color.G * $Factor),
        [int][Math]::Round($Color.B * $Factor))
}

# Spiegelt eine 8 Zeichen breite Haelfte zu einer vollen 16er-Zeile.
function Expand-Half {
    param([string[]]$Half)
    $rows = @()
    foreach ($row in $Half) {
        if ($row.Length -ne 8) {
            throw "Halbe Zeile muss 8 Zeichen haben, ist aber $($row.Length): '$row'"
        }
        $reversed = -join ($row.ToCharArray() | ForEach-Object { $_ })[($row.Length - 1)..0]
        $rows += ($row + $reversed)
    }
    return $rows
}

# Spiegelt ein volles 16er-Sprite horizontal.
function Get-Mirrored {
    param([string[]]$Rows)
    return @($Rows | ForEach-Object {
        -join ($_.ToCharArray())[($_.Length - 1)..0]
    })
}

function Assert-Sprite {
    param([string[]]$Rows, [string]$Name)
    if ($Rows.Count -ne $TILE) {
        throw "$Name : erwartet $TILE Zeilen, gefunden $($Rows.Count)"
    }
    for ($i = 0; $i -lt $Rows.Count; $i++) {
        if ($Rows[$i].Length -ne $TILE) {
            throw "$Name Zeile $i : erwartet $TILE Zeichen, gefunden $($Rows[$i].Length) ('$($Rows[$i])')"
        }
    }
}

# Zeichnet ein Sprite in die Bitmap. $bob verschiebt es fuer den Laufframe
# um einen Pixel nach oben -- ein billiger, aber wirksamer Lauf-Effekt.
function Write-Sprite {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string[]]$Rows,
        [int]$OriginX,
        [int]$OriginY,
        [hashtable]$Palette,
        [int]$Bob = 0
    )
    for ($y = 0; $y -lt $TILE; $y++) {
        for ($x = 0; $x -lt $TILE; $x++) {
            $ch = $Rows[$y][$x]
            if ($ch -eq '.') { continue }
            if (-not $Palette.ContainsKey([string]$ch)) {
                throw "Unbekanntes Zeichen '$ch' in der Pixelkarte."
            }
            $ty = $y - $Bob
            if ($ty -lt 0 -or $ty -ge $TILE) { continue }
            $Bitmap.SetPixel($OriginX + $x, $OriginY + $ty, $Palette[[string]$ch])
        }
    }
}


$down = Expand-Half $CAT_DOWN_HALF
$up = Expand-Half $CAT_UP_HALF
$left = $CAT_LEFT
$right = Get-Mirrored $CAT_LEFT

Assert-Sprite $down 'unten'
Assert-Sprite $up 'oben'
Assert-Sprite $left 'links'
Assert-Sprite $right 'rechts'

$directions = @($down, $up, $left, $right)
$framesPerDirection = 2
$columns = $directions.Count * $framesPerDirection

$sheet = New-Object System.Drawing.Bitmap ($columns * $TILE), ($VARIANTS.Count * $TILE), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

for ($v = 0; $v -lt $VARIANTS.Count; $v++) {
    $variant = $VARIANTS[$v]
    $base = ConvertFrom-Hex $variant.Base
    $palette = @{
        'o' = Get-Darkened $base
        'b' = $base
        'd' = ConvertFrom-Hex $variant.Dark
        'l' = ConvertFrom-Hex $variant.Light
        'e' = ConvertFrom-Hex $EYE_COLOR
        'p' = ConvertFrom-Hex $PINK_COLOR
        'w' = ConvertFrom-Hex $WHITE_COLOR
    }

    for ($d = 0; $d -lt $directions.Count; $d++) {
        for ($f = 0; $f -lt $framesPerDirection; $f++) {
            $col = $d * $framesPerDirection + $f
            Write-Sprite -Bitmap $sheet -Rows $directions[$d] `
                -OriginX ($col * $TILE) -OriginY ($v * $TILE) `
                -Palette $palette -Bob $f
        }
    }
}

$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$sheet.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Spritesheet geschrieben: $OutputPath ($($sheet.Width)x$($sheet.Height))"

if ($PreviewPath) {
    $scale = 8
    $preview = New-Object System.Drawing.Bitmap ($sheet.Width * $scale), ($sheet.Height * $scale)
    $g = [System.Drawing.Graphics]::FromImage($preview)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.Clear([System.Drawing.Color]::FromArgb(255, 60, 66, 78))
    $g.DrawImage($sheet, (New-Object System.Drawing.Rectangle 0, 0, $preview.Width, $preview.Height),
        0, 0, $sheet.Width, $sheet.Height, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $preview.Save($PreviewPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $preview.Dispose()
    Write-Host "Vorschau geschrieben: $PreviewPath"
}

$sheet.Dispose()
