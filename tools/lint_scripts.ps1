<#
.SYNOPSIS
    Prueft jedes GDScript im Projekt auf Uebersetzungsfehler.

.DESCRIPTION
    Godot meldet Parse-Fehler erst, wenn ein Skript zur Laufzeit gebraucht
    wird. Ein Fehler in einer selten betretenen Szene faellt damit erst beim
    Spielen auf -- oder gar erst dem Spieler.

    Jede Datei wird einzeln mit `godot --check-only --script` uebersetzt. Das
    ist der einzige zuverlaessige Weg: `load()` im laufenden Spiel liefert
    Skripte aus dem Zwischenspeicher und verschluckt Fehler, und ein erzwungenes
    Neuladen bringt die Engine zum Absturz.

    Weil `--check-only` ohne laufende Autoloads arbeitet, kennt es GameState und
    Co. nicht. Solche Meldungen werden herausgefiltert -- sie sind hier kein
    echter Fehler.

.EXAMPLE
    pwsh tools/lint_scripts.ps1

.EXAMPLE
    # Auch die gefilterten Meldungen anzeigen
    pwsh tools/lint_scripts.ps1 -Verbose
#>
[CmdletBinding()]
param(
    ## Wie viele Dateien gleichzeitig geprueft werden.
    [int]$Parallelism = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Godot = & (Join-Path $PSScriptRoot 'godot.ps1') --which
if (-not $Godot) { throw 'Godot wurde nicht gefunden.' }

# Namen, die es nur zur Laufzeit gibt. Meldungen dazu sind keine echten Fehler.
$AutoloadNames = @('GameState', 'SaveManager', 'AudioManager', 'SceneRouter')

$files = Get-ChildItem -Path $ProjectRoot -Filter '*.gd' -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\\.godot\\' } |
    Sort-Object FullName

Write-Host "Pruefe $($files.Count) Skript(e) mit $Godot"

$results = $files | ForEach-Object -ThrottleLimit $Parallelism -Parallel {
    $godot = $using:Godot
    $root = $using:ProjectRoot
    $autoloads = $using:AutoloadNames

    $relative = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    $resPath = "res://$relative"

    $output = & $godot --headless --path $root --check-only --script $resPath 2>&1 |
        Out-String
    $exitCode = $LASTEXITCODE

    # Fehler, die nur an fehlenden Autoloads haengen, herausfiltern.
    # "Failed to compile depended scripts" ist ein Folgefehler: das Skript
    # bindet ein anderes ein, das seinerseits nur an Autoloads scheitert.
    $errorLines = @()
    $autoloadOnly = $true
    foreach ($line in ($output -split "`r?`n")) {
        if ($line -notmatch 'SCRIPT ERROR|Parse Error|Compile Error') { continue }
        $errorLines += $line.Trim()

        $isAutoload = $false
        foreach ($name in $autoloads) {
            if ($line -match "Identifier not found: $name") { $isAutoload = $true; break }
        }
        if ($line -match 'Failed to compile depended scripts') { $isAutoload = $true }
        if (-not $isAutoload) { $autoloadOnly = $false }
    }

    $realErrors = if ($autoloadOnly) { @() } else { $errorLines }

    [PSCustomObject]@{
        Path       = $relative
        ExitCode   = $exitCode
        RealErrors = $realErrors
        RawOutput  = $output
    }
}

$broken = [System.Collections.Generic.List[object]]::new()
foreach ($result in ($results | Sort-Object Path)) {
    $realErrors = @($result.RealErrors)
    if ($realErrors.Count -gt 0) {
        $broken.Add($result)
        Write-Host "  [FEHLER] $($result.Path)" -ForegroundColor Red
        foreach ($line in $realErrors) {
            Write-Host "           $line" -ForegroundColor DarkRed
        }
    }
    elseif ($result.ExitCode -ne 0) {
        # Nur Autoload-Meldungen -- das ist in Ordnung.
        Write-Verbose "  [ok, nur Autoload-Meldungen] $($result.Path)"
    }
    else {
        Write-Verbose "  [ok] $($result.Path)"
    }
}

Write-Host ""
if ($broken.Count -eq 0) {
    Write-Host "Alle $($files.Count) Skripte uebersetzen fehlerfrei." -ForegroundColor Green
    exit 0
}

Write-Host "$($broken.Count) von $($files.Count) Skript(en) fehlerhaft." -ForegroundColor Red
exit 1
