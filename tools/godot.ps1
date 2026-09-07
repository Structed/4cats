<#
.SYNOPSIS
    Findet die Godot-Binary und fuehrt sie mit den uebergebenen Argumenten aus.

.DESCRIPTION
    Godot liegt selten auf dem PATH, und der Pfad unterscheidet sich je nach
    Rechner. Dieses Skript sucht in dieser Reihenfolge:

      1. Umgebungsvariable GODOT
      2. PATH (godot, godot4)
      3. uebliche Installationsorte des jeweiligen Betriebssystems

    Auf Windows wird die Konsolenfassung (..._console.exe) bevorzugt, weil nur
    sie ihre Ausgabe an die Konsole weitergibt -- ohne sie bleiben Testlaeufe
    und Fehlermeldungen unsichtbar.

    Das Skript deklariert bewusst keine eigenen Parameter: sobald PowerShell
    Parameter binden darf, verschluckt es das nackte `--`, mit dem Godot die
    Argumente fuer das Spiel abtrennt. Ueber $args kommt alles unveraendert an.

.EXAMPLE
    pwsh tools/godot.ps1 --headless --path . -- --test

.EXAMPLE
    # Nur den gefundenen Pfad ausgeben, nichts starten
    pwsh tools/godot.ps1 --which
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VERSION = '4.7.2'


function Get-GodotCandidate {
    # 1. Ausdrueckliche Vorgabe schlaegt alles andere.
    if ($env:GODOT) {
        if (Test-Path -LiteralPath $env:GODOT -PathType Leaf) { return $env:GODOT }
        Write-Warning "GODOT zeigt auf '$($env:GODOT)', dort liegt aber keine Datei."
    }

    # 2. PATH.
    foreach ($name in @('godot', 'godot4')) {
        $found = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { return $found.Source }
    }

    # 3. Uebliche Installationsorte.
    $patterns = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        @(
            "C:\Godot\Godot_v${VERSION}-stable_win64.exe\Godot_v${VERSION}-stable_win64_console.exe"
            "C:\Godot\*\Godot_v*_console.exe"
            "C:\Godot\Godot_v*_console.exe"
            "$env:LOCALAPPDATA\Programs\Godot\Godot_v*_console.exe"
            "$env:LOCALAPPDATA\Programs\Godot\*\Godot_v*_console.exe"
            "$env:ProgramFiles\Godot\Godot_v*_console.exe"
            "$env:USERPROFILE\scoop\apps\godot\current\godot.exe"
            # Fallback: Fenster-Fassung, falls keine Konsolenfassung vorliegt.
            "C:\Godot\*\Godot_v*.exe"
            "$env:LOCALAPPDATA\Programs\Godot\Godot_v*.exe"
        )
    } elseif ($IsMacOS) {
        @(
            '/Applications/Godot.app/Contents/MacOS/Godot'
            "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
        )
    } else {
        @(
            "$HOME/.local/bin/godot"
            '/usr/local/bin/godot'
            '/usr/bin/godot'
            "$HOME/godot/godot"
        )
    }

    foreach ($pattern in $patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        $match = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($match) { return $match.FullName }
    }

    return $null
}


$godot = Get-GodotCandidate

if (-not $godot) {
    throw @"
Godot $VERSION wurde nicht gefunden.

Setze die Umgebungsvariable GODOT auf die ausfuehrbare Datei, zum Beispiel:
  `$env:GODOT = 'C:\Godot\Godot_v${VERSION}-stable_win64.exe\Godot_v${VERSION}-stable_win64_console.exe'

Oder lege Godot in den PATH. Download: https://godotengine.org/download
"@
}

# Ohne Argumente oder mit --which nur den Fundort melden.
if ($args.Count -eq 0 -or $args[0] -in @('--which', '-which', '--where')) {
    Write-Output $godot
    exit 0
}

& $godot @args
exit $LASTEXITCODE
