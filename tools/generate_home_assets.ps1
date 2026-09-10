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
    }
}

$Items = [System.Drawing.Bitmap]::new(192, 96)
$G = [System.Drawing.Graphics]::FromImage($Items)
try {
    $G.Clear([System.Drawing.Color]::Transparent)
    for ($row = 0; $row -lt 3; $row++) {
        for ($column = 0; $column -lt 6; $column++) {
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

$Icons = [System.Drawing.Bitmap]::new(112, 16)
$G = [System.Drawing.Graphics]::FromImage($Icons)
try {
    $G.Clear([System.Drawing.Color]::Transparent)
    for ($column = 0; $column -lt 7; $column++) {
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
        }
        $G.ResetTransform()
    }
    $Icons.Save((Join-Path $Sprites 'home_icons.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally { $G.Dispose(); $Icons.Dispose() }

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
Write-Host 'Erzeugt: home_items.png (192x96), home_tiles.png (64x16), home_icons.png (112x16), home_tileset.tres'
