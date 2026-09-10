<#
.SYNOPSIS
    Startet das Spiel, nimmt ein Bild auf und beendet es wieder.

.DESCRIPTION
    Die Aufnahme passiert im Spiel selbst (ueber den Viewport), deshalb ist
    kein Fensterfokus noetig und es kann nicht versehentlich ein anderes
    Fenster erwischt werden.

.EXAMPLE
    pwsh tools/screenshot.ps1 -Scene rescue -OutputPath C:\temp\rescue.png
#>
[CmdletBinding()]
param(
    [ValidateSet('menu', 'home', 'rescue')]
    [string]$Scene = 'menu',

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$GodotPath = 'C:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',

    [int]$Width = 1280,
    [int]$Height = 720,

    ## Wie lange das Spiel laufen darf, bevor abgebrochen wird.
    [int]$TimeoutSeconds = 45,

    ## Fuellt vor der Aufnahme Beispieldaten ein (nuetzlich fuers Zuhause).
    [switch]$Demo,

    [switch]$Touch,

    [ValidateSet('play', 'furnish', 'placement')]
    [string]$HomeView = 'play'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $GodotPath)) { throw "Godot nicht gefunden: $GodotPath" }

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$targetDir = Split-Path $OutputPath -Parent
if ($targetDir -and -not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }

# Godot erwartet Vorwaertsschraegstriche im Pfad.
$godotOutput = (Join-Path (Resolve-Path $targetDir).Path (Split-Path $OutputPath -Leaf)) -replace '\\', '/'

$arguments = @(
    '--path', $ProjectRoot,
    '--resolution', "${Width}x${Height}",
    '--',
    "--start=$Scene",
    "--screenshot=$godotOutput"
)
if ($Demo) { $arguments += '--demo' }
if ($Touch) { $arguments += '--touch-preview' }
if ($HomeView -ne 'play') {
    if ($Scene -ne 'home') { throw 'HomeView ist nur fuer die Hausszene verfuegbar.' }
    $arguments += "--home-preview=$HomeView"
}

Write-Host "Starte: $Scene -> $godotOutput"
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -PassThru -NoNewWindow

if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force
    throw "Zeitueberschreitung nach $TimeoutSeconds s."
}

if (-not (Test-Path $OutputPath)) {
    throw "Kein Bild entstanden (Exit-Code $($process.ExitCode))."
}

$size = (Get-Item $OutputPath).Length
Write-Host "Screenshot: $OutputPath ($size Bytes)"
