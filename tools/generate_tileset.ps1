<#
.SYNOPSIS
    Erzeugt resources/urban_tileset.tres aus dem Kenney RPG Urban Pack.

.DESCRIPTION
    Das Tileset hat 27 x 18 Kacheln a 16 px. Alle Kacheln werden angelegt,
    damit sie im Editor verfuegbar sind; eine kuratierte Auswahl bekommt
    zusaetzlich eine Kollisionsflaeche (Gebaeude, Wasser, Baeume, Zaeune).

    Der Generator ist idempotent -- er ueberschreibt die Zieldatei komplett.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\resources\urban_tileset.tres")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$COLUMNS = 27
$ROWS = 18
$TILE = 16

# Rechtecke (SpalteVon, ZeileVon, SpalteBis, ZeileBis), die undurchlaessig sind.
$SolidRegions = @(
    @{ Name = 'Backsteinwaende'; C0 = 16; R0 = 0;  C1 = 22; R1 = 7 }
    @{ Name = 'Wasser';          C0 = 8;  R0 = 6;  C1 = 15; R1 = 8 }
    @{ Name = 'Baeume';          C0 = 16; R0 = 8;  C1 = 22; R1 = 13 }
    @{ Name = 'Zaeune';          C0 = 0;  R0 = 8;  C1 = 7;  R1 = 9 }
)

function Test-Solid {
    param([int]$Col, [int]$Row)
    foreach ($r in $SolidRegions) {
        if ($Col -ge $r.C0 -and $Col -le $r.C1 -and $Row -ge $r.R0 -and $Row -le $r.R1) {
            return $true
        }
    }
    return $false
}

$half = $TILE / 2
$polygon = "PackedVector2Array(-$half, -$half, $half, -$half, $half, $half, -$half, $half)"

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('[gd_resource type="TileSet" load_steps=3 format=3]')
[void]$sb.AppendLine()
[void]$sb.AppendLine('[ext_resource type="Texture2D" path="res://assets/kenney/urban_tilemap.png" id="1_atlas"]')
[void]$sb.AppendLine()
[void]$sb.AppendLine('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_urban"]')
[void]$sb.AppendLine('texture = ExtResource("1_atlas")')
[void]$sb.AppendLine("texture_region_size = Vector2i($TILE, $TILE)")

$solidCount = 0
for ($row = 0; $row -lt $ROWS; $row++) {
    for ($col = 0; $col -lt $COLUMNS; $col++) {
        [void]$sb.AppendLine("${col}:${row}/0 = 0")
        if (Test-Solid -Col $col -Row $row) {
            [void]$sb.AppendLine("${col}:${row}/0/physics_layer_0/polygon_0/points = $polygon")
            $solidCount++
        }
    }
}

[void]$sb.AppendLine()
[void]$sb.AppendLine('[resource]')
[void]$sb.AppendLine('physics_layer_0/collision_layer = 1')
[void]$sb.AppendLine('physics_layer_0/collision_mask = 0')
[void]$sb.AppendLine("tile_size = Vector2i($TILE, $TILE)")
[void]$sb.AppendLine('sources/0 = SubResource("TileSetAtlasSource_urban")')

$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$dir = Split-Path $OutputPath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

Write-Host "Tileset geschrieben: $OutputPath"
Write-Host "  Kacheln gesamt : $($COLUMNS * $ROWS)"
Write-Host "  davon fest     : $solidCount"
