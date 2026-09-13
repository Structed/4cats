<#
.SYNOPSIS
    Erzeugt die originalen Pixelgrafiken und das TileSet fuer das Katzenhaus.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$Root = Split-Path $PSScriptRoot -Parent
$Sprites = Join-Path $Root 'assets\sprites'
$Resources = Join-Path $Root 'resources'
New-Item -ItemType Directory -Force -Path $Sprites, $Resources | Out-Null

function Box($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Color))
    try { $G.FillRectangle($brush, $X, $Y, $W, $H) } finally { $brush.Dispose() }
}

function Oval($G, [string]$Color, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Color))
    try { $G.FillEllipse($brush, $X, $Y, $W, $H) } finally { $brush.Dispose() }
}

function Spark($G, [int]$X, [int]$Y, [string]$Color = '#fff8df') {
    Box $G $Color ($X + 1) $Y 1 5
    Box $G $Color ($X - 1) ($Y + 2) 5 1
}

function Paint-Item($G, [int]$Kind, [int]$State) {
    if ($Kind -eq 4) {
        Oval $G '#a38362' 8 23 16 4
        Oval $G '#51404e' 7 7 18 18
        Oval $G '#e57689' 8 8 16 16
        Box $G '#f6c775' (13 + $State) 9 4 14
        Box $G '#f6c775' 9 (13 + $State) 14 4
        Box $G '#fff1d0' 11 10 3 2
        return
    }
    Oval $G '#a38362' 2 25 28 5
    switch ($Kind) {
        0 {
            Oval $G '#594139' 2 8 28 21
            Oval $G '#bf6854' 3 8 26 18
            Oval $G '#e49a76' 4 8 24 15
            Oval $G '#754a3c' 6 10 20 11
            Box $G '#f8c49a' 7 23 18 2
            if ($State -gt 0) {
                foreach ($point in @(@(9,13), @(14,11), @(19,13), @(12,17), @(18,17))) {
                    Box $G '#e5b865' $point[0] $point[1] 4 3
                    Box $G '#a3733e' $point[0] ($point[1] + 2) 3 1
                }
            }
        }
        1 {
            Oval $G '#3d5962' 2 8 28 21
            Oval $G '#719fa4' 3 8 26 18
            Oval $G '#c1e2d9' 4 8 24 15
            Oval $G '#687e84' 6 10 20 11
            Box $G '#b5d6d4' 7 23 18 2
            if ($State -gt 0) {
                Oval $G '#559fd1' 6 10 20 11
                Box $G '#a3e3ef' 8 13 7 2
                Box $G '#d4f5f1' 17 17 6 1
            }
        }
        2 {
            Box $G '#5b6571' 5 25 4 5
            Box $G '#5b6571' 23 25 4 5
            Box $G '#53626c' 1 6 30 21
            Box $G '#e8ecdf' 2 5 28 20
            Box $G '#b8ced2' 4 7 24 16
            Box $G '#659cbb' 6 9 20 12
            Box $G '#a8dbdf' 8 11 16 8
            Box $G '#53626c' 13 0 6 10
            Box $G '#d9e2de' 14 1 4 7
            Box $G '#eff5e9' 15 6 8 3
            if ($State -gt 0) {
                foreach ($point in @(@(7,14), @(17,12), @(21,17))) {
                    Oval $G '#f6fffa' $point[0] ($point[1] - $State) 5 5
                    Oval $G '#bce4ee' ($point[0] + 1) ($point[1] - $State + 1) 2 2
                }
            }
        }
        3 {
            Box $G '#684e44' 4 25 4 6
            Box $G '#684e44' 24 25 4 6
            Box $G '#684e44' 1 6 30 22
            Box $G '#bb8c69' 2 5 28 20
            Box $G '#e8d4ac' 4 7 24 16
            Box $G '#fff0cb' 5 8 22 13
            Box $G '#b2d4c6' 7 9 9 10
            Box $G '#488879' 10 10 3 8
            Box $G '#488879' 8 12 7 3
            Box $G '#697880' 20 9 3 10
            Box $G '#b6cbd0' 19 12 5 5
            if ($State -gt 0) {
                Spark $G 3 0 '#dff2c8'
                Spark $G 25 (1 + $State) '#dff2c8'
            }
        }
        5 {
            Box $G '#4e596a' 2 6 28 23
            Box $G '#8b9ca6' 3 5 26 20
            Box $G '#c3b39c' 5 8 22 15
            Box $G '#e5d3a6' 6 9 20 12
            foreach ($point in @(@(8,10), @(14,12), @(20,10), @(9,17), @(18,18), @(23,16))) {
                Box $G '#b79c77' $point[0] $point[1] 2 1
            }
            Box $G '#b7c8cc' 5 25 22 2
            if ($State -gt 0) {
                Box $G '#876348' 9 13 6 5
                Box $G '#af8055' 10 12 4 3
            }
            if ($State -gt 1) {
                Box $G '#876348' 19 11 5 4
                Box $G '#876348' 16 18 6 3
                Box $G '#9a955b' 7 1 2 4
                Box $G '#9a955b' 18 0 2 4
            }
        }
        6 {
            Box $G '#684e44' 4 25 4 6
            Box $G '#684e44' 23 25 4 6
            Box $G '#614b40' 2 2 28 26
            Box $G '#b88557' 3 3 26 24
            Box $G '#e2b47a' 4 3 24 3
            Box $G '#765039' 6 7 20 17
            Box $G '#cea26d' 6 14 20 2
            Box $G '#cea26d' 6 23 20 2
            Box $G '#e2b47a' 4 7 2 18
            Box $G '#e2b47a' 26 7 2 18
            if ($State -gt 0) {
                Box $G '#d9a964' 8 8 6 6
                Box $G '#fff0cb' 10 9 2 4
                Box $G '#a65f53' 17 8 6 6
                Box $G '#f6c775' 18 10 4 2
                Box $G '#d9a964' 8 17 8 6
                Box $G '#fff0cb' 11 17 2 6
            }
            if ($State -gt 1) {
                Box $G '#92aa77' 19 17 5 6
                Box $G '#e6edcb' 20 18 3 2
            }
        }
        7 {
            Box $G '#4c6470' 4 25 4 5
            Box $G '#4c6470' 23 25 4 5
            Box $G '#4c6470' 2 13 28 14
            Box $G '#93b8b5' 3 14 26 11
            Box $G '#d5e6d7' 4 14 24 3
            Box $G '#6d939a' 6 18 20 6
            Box $G '#476775' 8 2 5 12
            Box $G '#476775' 10 1 13 5
            Box $G '#476775' 20 4 4 6
            Box $G '#cde1db' 9 3 3 9
            Box $G '#cde1db' 12 2 10 2
            Box $G '#cde1db' 21 4 2 4
            Box $G '#7eaac0' 5 6 6 2
            Box $G '#eff5e9' 7 4 2 5
            Box $G '#426c87' 15 11 12 12
            Box $G '#8cc4d1' 16 12 10 10
            Box $G '#def0e7' 17 12 8 2
            if ($State -gt 0) {
                Box $G '#559fd1' 17 15 8 5
                Box $G '#b7eced' 18 15 5 1
            }
            if ($State -gt 1) { Box $G '#a3e3ef' 21 9 2 3 }
        }
    }
}

$Items = [System.Drawing.Bitmap]::new(256, 96)
$G = [System.Drawing.Graphics]::FromImage($Items)
try {
    $G.Clear([System.Drawing.Color]::Transparent)
    for ($row = 0; $row -lt 3; $row++) {
        for ($column = 0; $column -lt 8; $column++) {
            $G.TranslateTransform($column * 32, $row * 32)
            Paint-Item $G $column $row
            $G.ResetTransform()
        }
    }
    $Items.Save((Join-Path $Sprites 'home_items.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally { $G.Dispose(); $Items.Dispose() }

$Tiles = [System.Drawing.Bitmap]::new(64, 16)
$G = [System.Drawing.Graphics]::FromImage($Tiles)
try {
    for ($column = 0; $column -lt 4; $column++) {
        $G.TranslateTransform($column * 16, 0)
        Box $G '#d9b88a' 0 0 16 16
        if ($column -eq 1) { Box $G '#d3ad7e' 0 0 16 16 }
        Box $G '#bf9569' 0 7 16 1
        Box $G '#bf9569' 0 15 16 1
        Box $G '#bf9569' 5 0 1 7
        Box $G '#bf9569' 12 8 1 7
        Box $G '#e6c999' 1 1 3 1
        Box $G '#e6c999' 7 9 4 1
        if ($column -eq 2) {
            Box $G '#605046' 0 0 16 16
            Box $G '#e5ddbc' 1 1 14 10
            Box $G '#c5c6a2' 1 8 14 3
            Box $G '#a27e58' 0 12 16 3
        } elseif ($column -eq 3) {
            Box $G '#446c60' 1 1 14 15
            Box $G '#81a786' 3 3 10 12
            Box $G '#e2efd2' 7 5 2 7
            Box $G '#e2efd2' 5 8 6 2
            Box $G '#e2efd2' 6 10 4 2
        }
        $G.ResetTransform()
    }
    $Tiles.Save((Join-Path $Sprites 'home_tiles.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally { $G.Dispose(); $Tiles.Dispose() }

$Icons = [System.Drawing.Bitmap]::new(144, 16)
$G = [System.Drawing.Graphics]::FromImage($Icons)
try {
    $G.Clear([System.Drawing.Color]::Transparent)
    for ($column = 0; $column -lt 9; $column++) {
        $G.TranslateTransform($column * 16, 0)
        switch ($column) {
            0 {
                Oval $G '#765039' 2 6 12 8
                Oval $G '#d5a256' 3 5 10 7
                Box $G '#765039' 5 6 2 2
                Box $G '#765039' 9 8 2 2
            }
            1 {
                Box $G '#3f739f' 7 2 2 3
                Box $G '#3f739f' 5 5 6 3
                Oval $G '#3f739f' 3 6 10 9
                Oval $G '#70c3de' 4 6 8 7
                Box $G '#d1f0e9' 6 7 2 3
            }
            2 {
                Box $G '#789db6' 2 7 11 7
                Box $G '#b7dbe3' 3 8 9 5
                Oval $G '#789db6' 7 1 7 7
                Oval $G '#eaf8ef' 8 2 5 5
                Oval $G '#a1c4d8' 2 3 4 4
            }
            3 {
                Box $G '#315b54' 6 2 5 13
                Box $G '#315b54' 2 6 13 5
                Box $G '#69a485' 7 3 3 11
                Box $G '#69a485' 3 7 11 3
            }
            4 {
                Oval $G '#664757' 2 2 13 13
                Oval $G '#e88797' 3 3 11 11
                Box $G '#ffe2a2' 7 3 3 11
                Box $G '#ffe2a2' 3 7 11 3
            }
            5 {
                Box $G '#566574' 1 5 14 9
                Box $G '#a0b8c0' 2 6 12 6
                Box $G '#e5d5a9' 3 7 10 4
                Box $G '#87664f' 7 8 4 2
            }
            6 {
                Box $G '#b35a68' 2 3 5 7
                Box $G '#b35a68' 9 3 5 7
                Box $G '#b35a68' 4 6 8 7
                Box $G '#b35a68' 6 11 4 4
                Box $G '#f0979f' 3 4 3 4
                Box $G '#f0979f' 10 4 3 4
                Box $G '#f0979f' 5 7 6 4
                Box $G '#f0979f' 7 10 2 3
            }
            7 {
                Box $G '#614b40' 2 1 12 14
                Box $G '#c99763' 3 2 10 12
                Box $G '#765039' 4 4 8 4
                Box $G '#765039' 4 9 8 4
                Box $G '#e7bd7b' 5 5 3 3
                Box $G '#a65f53' 9 5 2 3
                Box $G '#e7bd7b' 5 10 5 3
                Box $G '#fff0cb' 6 10 1 3
            }
            8 {
                Box $G '#476775' 4 1 3 12
                Box $G '#476775' 6 1 7 3
                Box $G '#476775' 11 3 3 3
                Box $G '#cde1db' 5 2 1 8
                Box $G '#cde1db' 7 2 5 1
                Box $G '#7eaac0' 2 5 5 2
                Box $G '#559fd1' 11 7 2 3
                Box $G '#559fd1' 10 10 4 3
                Box $G '#b7eced' 11 10 1 2
                Box $G '#93b8b5' 2 13 12 2
            }
        }
        $G.ResetTransform()
    }
    $Icons.Save((Join-Path $Sprites 'home_icons.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally { $G.Dispose(); $Icons.Dispose() }

$Cargo = [System.Drawing.Bitmap]::new(48, 16)
$G = [System.Drawing.Graphics]::FromImage($Cargo)
try {
    $G.Clear([System.Drawing.Color]::Transparent)
    for ($column = 0; $column -lt 3; $column++) {
        $G.TranslateTransform($column * 16, 0)
        switch ($column) {
            0 {
                Box $G '#684e44' 3 4 10 11
                Box $G '#d9956b' 4 5 8 9
                Box $G '#f5c38a' 3 5 10 2
                Box $G '#765039' 4 3 8 3
                Box $G '#e7bd7b' 5 2 3 3
                Box $G '#e7bd7b' 9 3 2 2
                Box $G '#fff0cb' 6 9 4 3
                Box $G '#a3733e' 7 10 2 1
            }
            1 {
                Box $G '#426c87' 4 1 8 6
                Box $G '#cde1db' 5 2 6 3
                Box $G '#426c87' 2 5 12 9
                Box $G '#8cc4d1' 3 6 10 7
                Box $G '#559fd1' 4 6 8 3
                Box $G '#b7eced' 5 6 5 1
                Box $G '#def0e7' 4 10 2 2
                Box $G '#426c87' 4 14 8 1
            }
            2 {
                Box $G '#684e44' 1 3 14 11
                Box $G '#bc8551' 2 4 12 9
                Box $G '#e2b47a' 2 3 12 3
                Box $G '#f7dfaa' 7 3 3 10
                Box $G '#ad7746' 2 6 12 1
                Box $G '#e9ebcd' 3 8 4 4
                Box $G '#60866c' 4 9 2 2
                Box $G '#835b40' 11 11 2 1
            }
        }
        $G.ResetTransform()
    }
    $Cargo.Save((Join-Path $Sprites 'supply_cargo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally { $G.Dispose(); $Cargo.Dispose() }

$TileSet = @'
[gd_resource type="TileSet" load_steps=3 format=3]

[ext_resource type="Texture2D" path="res://assets/sprites/home_tiles.png" id="1_tiles"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_home"]
texture = ExtResource("1_tiles")
texture_region_size = Vector2i(16, 16)
0:0/0 = 0
1:0/0 = 0
2:0/0 = 0
3:0/0 = 0

[resource]
tile_size = Vector2i(16, 16)
sources/0 = SubResource("TileSetAtlasSource_home")
'@
[System.IO.File]::WriteAllText((Join-Path $Resources 'home_tileset.tres'),
    $TileSet.Replace("`r`n", "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Host 'Erzeugt: home_items.png (256x96), home_tiles.png (64x16), home_icons.png (144x16), supply_cargo.png (48x16), home_tileset.tres'
