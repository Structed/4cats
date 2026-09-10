<#
.SYNOPSIS
    Holt die verwendeten CC0-Assets von Kenney und legt sie im Projekt ab.

.DESCRIPTION
    Nur die tatsaechlich benutzten Dateien landen unter assets/ und damit im
    Repository -- die kompletten Pakete waeren um ein Vielfaches groesser.
    Das Skript ist idempotent: bereits vorhandene Downloads werden
    wiederverwendet, vorhandene Zieldateien ueberschrieben.

    Alle Pakete stehen unter CC0 (Public Domain), siehe CREDITS.md.

.EXAMPLE
    pwsh tools/install_assets.ps1
#>
[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$DownloadDir = Join-Path $ProjectRoot 'assets\_downloads'

# Paketname -> Download-URL (alle CC0, Quelle kenney.nl)
$Packs = [ordered]@{
    'rpg-urban-pack'   = 'https://kenney.nl/media/pages/assets/rpg-urban-pack/0a097d1dc7-1677578575/kenney_rpg-urban-pack.zip'
    'interface-sounds' = 'https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip'
    'impact-sounds'    = 'https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip'
}

# Paket -> (Eintrag im Zip -> Ziel relativ zum Projekt)
$FileMap = [ordered]@{
    'rpg-urban-pack'   = [ordered]@{
        'Tilemap/tilemap_packed.png' = 'assets/kenney/urban_tilemap.png'
        'Tilemap/tilemap.txt'        = 'assets/kenney/urban_tilemap.txt'
        'License.txt'                = 'assets/kenney/rpg-urban-pack.license.txt'
    }
    'interface-sounds' = [ordered]@{
        'Audio/click_001.ogg'        = 'assets/audio/ui_click.ogg'
        'Audio/back_001.ogg'         = 'assets/audio/ui_back.ogg'
        'Audio/confirmation_001.ogg' = 'assets/audio/pickup.ogg'
        'Audio/confirmation_004.ogg' = 'assets/audio/deliver.ogg'
        'Audio/drop_002.ogg'         = 'assets/audio/care.ogg'
        'Audio/bong_001.ogg'         = 'assets/audio/adopt.ogg'
        'Audio/maximize_006.ogg'     = 'assets/audio/coins.ogg'
        # Platzhalter: bis ein echtes Miauen vorliegt, gibt es wenigstens
        # eine hoerbare Rueckmeldung. Datei einfach ersetzen.
        'Audio/confirmation_003.ogg' = 'assets/audio/meow.ogg'
        'License.txt'                = 'assets/audio/interface-sounds.license.txt'
    }
    'impact-sounds'    = [ordered]@{
        'Audio/impactSoft_medium_000.ogg' = 'assets/audio/scare.ogg'
        'License.txt'                     = 'assets/audio/impact-sounds.license.txt'
    }
}


function Get-Pack {
    param([string]$Name, [string]$Url)
    $zipPath = Join-Path $DownloadDir "$Name.zip"
    if ((Test-Path $zipPath) -and -not $Force) {
        Write-Host "  [cache] $Name"
        return $zipPath
    }
    New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
    Write-Host "  [lade ] $Name"
    curl.exe -sSL --fail --retry 3 -o $zipPath $Url
    if ($LASTEXITCODE -ne 0) { throw "Download fehlgeschlagen: $Name ($Url)" }
    return $zipPath
}

function Copy-FromZip {
    param([string]$ZipPath, [System.Collections.Specialized.OrderedDictionary]$Map)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($entryName in $Map.Keys) {
            $entry = $zip.Entries | Where-Object { $_.FullName -eq $entryName } | Select-Object -First 1
            if ($null -eq $entry) {
                Write-Warning "    Eintrag fehlt im Zip: $entryName"
                continue
            }
            $target = Join-Path $ProjectRoot ($Map[$entryName] -replace '/', '\')
            $targetDir = Split-Path $target -Parent
            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
            if (Test-Path $target) { Remove-Item $target -Force }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            Write-Host "    -> $($Map[$entryName])"
        }
    }
    finally {
        $zip.Dispose()
    }
}


Write-Host "Projekt: $ProjectRoot"
foreach ($name in $Packs.Keys) {
    Write-Host "== $name"
    $zipPath = Get-Pack -Name $name -Url $Packs[$name]
    Copy-FromZip -ZipPath $zipPath -Map $FileMap[$name]
}

Write-Host ""
Write-Host "Erzeuge die eigenen Katzen-Sprites..."
& (Join-Path $PSScriptRoot 'generate_cat_sprites.ps1')
& (Join-Path $PSScriptRoot 'generate_home_assets.ps1')

Write-Host ""
Write-Host "Fertig. Rohdownloads liegen in assets/_downloads (nicht im Repository)."
