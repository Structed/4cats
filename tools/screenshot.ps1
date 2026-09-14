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

    [string]$GodotPath = '',

    [int]$Width = 1280,
    [int]$Height = 720,

    ## Wie lange das Spiel laufen darf, bevor abgebrochen wird.
    [int]$TimeoutSeconds = 45,

    ## Fuellt vor der Aufnahme Beispieldaten ein (nuetzlich fuers Zuhause).
    [switch]$Demo,

    [switch]$Touch,

    [ValidateSet('play', 'furnish', 'placement', 'cat', 'supplies', 'parcel', 'critical')]
    [string]$HomeView = 'play',

    [ValidateSet('play', 'default', 'difficulty', 'options', 'analytics')]
    [string]$MenuView = 'play',

    [ValidateSet('play', 'shop')]
    [string]$RescueView = 'play',

    [ValidateSet('relaxed', 'challenging', 'realistic')]
    [string]$DemoMode = 'relaxed',

    ## Darstellungsart der Knoepfe; siehe UiKit.IconMode.
    [ValidateSet('default', 'text', 'both', 'icon')]
    [string]$Buttons = 'default'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$previousGodot = $env:GODOT
try {
    if ($GodotPath) { $env:GODOT = $GodotPath }
    $GodotPath = & (Join-Path $PSScriptRoot 'godot.ps1') --which
}
finally {
    $env:GODOT = $previousGodot
}
if (-not $GodotPath -or -not (Test-Path $GodotPath)) { throw "Godot nicht gefunden: $GodotPath" }

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath, $PWD.Path)

$targetDir = Split-Path $OutputPath -Parent
if ($targetDir -and -not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }

# Godot erwartet Vorwaertsschraegstriche im Pfad.
$godotOutput = (Join-Path (Resolve-Path $targetDir).Path (Split-Path $OutputPath -Leaf)) -replace '\\', '/'

$arguments = @(
    '--path', $ProjectRoot,
    '--resolution', "${Width}x${Height}",
    '--log-file', "$OutputPath.log",
    '--',
    "--start=$Scene",
    "--screenshot=$godotOutput"
)
if ($Demo) { $arguments += '--demo', "--demo-mode=$DemoMode" }
elseif ($DemoMode -ne 'relaxed' -or $HomeView -in @('parcel', 'critical')) {
    throw 'DemoMode und die Paket-/Risikovorschau brauchen -Demo.'
}
if ($Touch) { $arguments += '--touch-preview' }
if ($Buttons -ne 'default') { $arguments += "--buttons=$Buttons" }
if ($MenuView -notin @('play', 'default')) {
    if ($Scene -ne 'menu') { throw 'MenuView ist nur fuer das Hauptmenue verfuegbar.' }
    $arguments += "--menu-preview=$MenuView"
}
if ($HomeView -ne 'play') {
    if ($Scene -ne 'home') { throw 'HomeView ist nur fuer die Hausszene verfuegbar.' }
    $arguments += "--home-preview=$HomeView"
}
if ($RescueView -ne 'play') {
    if ($Scene -ne 'rescue') { throw 'RescueView ist nur fuer die Rettungsszene verfuegbar.' }
    $arguments += "--rescue-preview=$RescueView"
}

Write-Host "Starte: $Scene -> $godotOutput"
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -PassThru -NoNewWindow

if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force
    throw "Zeitueberschreitung nach $TimeoutSeconds s."
}

if ($process.ExitCode -ne 0) {
    throw "Godot hat die Aufnahme mit Exit-Code $($process.ExitCode) abgebrochen. Siehe $OutputPath.log"
}

if (-not (Test-Path $OutputPath)) {
    throw "Kein Bild entstanden (Exit-Code $($process.ExitCode))."
}

$size = (Get-Item $OutputPath).Length
Write-Host "Screenshot: $OutputPath ($size Bytes)"
