<#
.SYNOPSIS
    Bettet die explizite Analytics-Freigabe vor einem Release-Export ein.

.DESCRIPTION
    Ohne -Enabled werden Freigabe, Token und Kontakt geloescht. Es werden keine
    Umgebungsvariablen automatisch gelesen. Aktivierung verlangt einen
    oeffentlichen PostHog-Projekt-Token (phc_ plus Buchstaben/Ziffern) und einen
    nicht leeren, druckbaren Betreiberkontakt. Keine Personal-/Admin-Schluessel.
    Alle Eingaben und die drei vorhandenen [analytics]-Felder werden vor dem
    Schreiben geprueft. Andere Inhalte, Zeilenenden und UTF-8-BOM bleiben erhalten.

.EXAMPLE
    pwsh tools\configure_analytics.ps1

.EXAMPLE
    .\tools\configure_analytics.ps1 -Enabled -ProjectToken $env:POSTHOG_PROJECT_TOKEN `
        -PrivacyContact $env:ANALYTICS_PRIVACY_CONTACT

.EXAMPLE
    .\tools\configure_analytics.ps1 -Enabled:$false -ProjectRoot .\fixture
#>
[CmdletBinding()]
param(
    [switch]$Enabled,
    [AllowEmptyString()][string]$ProjectToken = '',
    [AllowEmptyString()][string]$PrivacyContact = '',
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false, $true)

if ($Enabled) {
    if ($ProjectToken -cnotmatch '\Aphc_[A-Za-z0-9]+\z') {
        throw 'Analytics aktiviert: ProjectToken muss ein oeffentlicher PostHog-Projekt-Token sein (phc_ plus Buchstaben/Ziffern), kein Personal-/Admin-Schluessel.'
    }
    if ([string]::IsNullOrWhiteSpace($PrivacyContact) -or
        $PrivacyContact -match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]') {
        throw 'Analytics aktiviert: PrivacyContact muss ein nicht leerer, druckbarer Betreiberkontakt ohne Steuerzeichen oder Zeilenumbrueche sein.'
    }
    try {
        $null = $utf8.GetBytes($PrivacyContact)
    } catch {
        throw 'Analytics aktiviert: PrivacyContact enthaelt ungueltige Unicode-Zeichen.'
    }
    $PrivacyContact = $PrivacyContact.Trim()
} else {
    $ProjectToken = ''
    $PrivacyContact = ''
}

function ConvertTo-GodotString {
    param([string]$Value)
    '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$projectPath = Join-Path $ProjectRoot 'project.godot'
if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw 'project.godot fehlt im angegebenen ProjectRoot.'
}
$projectPath = (Resolve-Path -LiteralPath $projectPath).ProviderPath
$bytes = [IO.File]::ReadAllBytes($projectPath)
$hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and
    $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
$offset = if ($hasBom) { 3 } else { 0 }
try {
    $text = $utf8.GetString($bytes, $offset, $bytes.Length - $offset)
} catch {
    throw 'project.godot muss gueltiges UTF-8 enthalten.'
}

$section = ''
$analyticsSections = 0
$insideString = $false
$settings = @{}
$keyPattern = '(?:"(?<key>enabled|project_token|privacy_contact)"|(?<key>enabled|project_token|privacy_contact))'
$assignmentPattern = '^(?<prefix>[ \t]*' + $keyPattern +
    '[ \t]*=[ \t]*)(?<value>true|false|"(?:[^"\\]|\\.)*")(?<suffix>[ \t]*(?:;.*)?)$'

foreach ($line in [regex]::Matches($text, '(?<body>[^\r\n]*)(?:\r\n|\n|\r|$)')) {
    $body = $line.Groups['body'].Value
    if (-not $insideString) {
        $header = [regex]::Match($body, '^[ \t]*\[(?<section>[^\]]+)\][ \t]*(?:;.*)?$')
        if ($header.Success) {
            $section = $header.Groups['section'].Value
            if ($section -ceq 'analytics') { $analyticsSections++ }
        } elseif ($section -ceq 'analytics') {
            $keyMatch = [regex]::Match($body, '^[ \t]*' + $keyPattern + '[ \t]*=')
            if ($keyMatch.Success) {
                $key = $keyMatch.Groups['key'].Value
                if ($settings.ContainsKey($key)) {
                    throw "analytics/$key ist mehrfach vorhanden."
                }
                $assignment = [regex]::Match($body, $assignmentPattern)
                if (-not $assignment.Success -or
                    (($key -ceq 'enabled') -eq $assignment.Groups['value'].Value.StartsWith('"'))) {
                    throw "analytics/$key muss als einzeiliger boolescher Wert beziehungsweise Godot-String vorliegen."
                }
                $value = $assignment.Groups['value']
                $settings[$key] = [pscustomobject]@{
                    Key = $key
                    Start = $line.Index + $value.Index
                    Length = $value.Length
                }
            }
        }
    }

    # Abschnitts- und Schluesseltext in mehrzeiligen Strings ist keine Konfiguration.
    $escaped = $false
    foreach ($character in $body.ToCharArray()) {
        if ($escaped) {
            $escaped = $false
        } elseif ($insideString) {
            if ($character -ceq '\') { $escaped = $true }
            elseif ($character -ceq '"') { $insideString = $false }
        } elseif ($character -ceq ';') {
            break
        } elseif ($character -ceq '"') {
            $insideString = $true
        }
    }
}

if ($insideString) { throw 'project.godot enthaelt einen nicht abgeschlossenen String.' }
if ($analyticsSections -ne 1) { throw 'project.godot muss genau einen [analytics]-Abschnitt enthalten.' }
foreach ($key in @('enabled', 'project_token', 'privacy_contact')) {
    if (-not $settings.ContainsKey($key)) { throw "analytics/$key fehlt." }
}

$values = @{
    enabled = if ($Enabled) { 'true' } else { 'false' }
    project_token = ConvertTo-GodotString $ProjectToken
    privacy_contact = ConvertTo-GodotString $PrivacyContact
}
$updated = $text
foreach ($setting in ($settings.Values | Sort-Object Start -Descending)) {
    $updated = $updated.Remove($setting.Start, $setting.Length).Insert($setting.Start, $values[$setting.Key])
}
$outputBytes = $utf8.GetBytes($updated)
if ($hasBom) { $outputBytes = [byte[]](@(0xEF, 0xBB, 0xBF) + $outputBytes) }

if ($updated -cne $text) {
    $pendingPath = Join-Path (Split-Path $projectPath -Parent) ".analytics-config-$([guid]::NewGuid().ToString('N')).pending"
    try {
        [IO.File]::WriteAllBytes($pendingPath, $outputBytes)
        [IO.File]::Move($pendingPath, $projectPath, $true)
    } finally {
        if (Test-Path -LiteralPath $pendingPath) { Remove-Item -LiteralPath $pendingPath -Force }
    }
}

[pscustomobject]@{ Enabled = $Enabled.IsPresent }
