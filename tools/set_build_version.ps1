<#
.SYNOPSIS
    Synchronisiert die Build-Version anhand der vollstaendigen Git-Historie.

.DESCRIPTION
    MAJOR.MINOR kommt aus project.godot, PATCH und Android-versionCode aus
    der Anzahl der First-Parent-Commits bis HEAD. Derselbe Commit behaelt
    dadurch auch bei wiederholten oder plattformfremden Builds seine Version.
    Gibt VersionName, VersionCode und ReleaseTag als Objekt zurueck.

.EXAMPLE
    $version = & tools/set_build_version.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Find-Setting {
    param([string]$Content, [string]$Section, [string]$Key)

    $sectionPattern = '(?ms)^\[' + [regex]::Escape($Section) +
        '\][ \t]*\r?\n(?<body>.*?)(?=^\[[^\]\r\n]+\][ \t]*\r?$|\z)'
    $sections = [regex]::Matches($Content, $sectionPattern)
    if ($sections.Count -ne 1) {
        throw "Konfigurationsabschnitt [$Section] fehlt oder ist mehrfach vorhanden."
    }
    $body = $sections[0].Groups['body']
    $keyPattern = '(?m)^[ \t]*' + [regex]::Escape($Key) +
        '[ \t]*=[ \t]*(?<value>[^\r\n]*?)[ \t]*\r?$'
    $settings = [regex]::Matches($body.Value, $keyPattern)
    if ($settings.Count -ne 1) {
        throw "Einstellung [$Section] $Key fehlt oder ist mehrfach vorhanden."
    }
    $value = $settings[0].Groups['value']
    [pscustomobject]@{
        Value = $value.Value
        Index = $body.Index + $value.Index
        Length = $value.Length
    }
}

function Set-Setting {
    param([string]$Content, [string]$Section, [string]$Key, [string]$Value)

    $setting = Find-Setting $Content $Section $Key
    $Content.Remove($setting.Index, $setting.Length).Insert($setting.Index, $Value)
}

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$shallow = & git -C $root rev-parse --is-shallow-repository
if ($LASTEXITCODE -ne 0) {
    throw 'Die Git-Historie des Projekts konnte nicht gelesen werden.'
}
if ($shallow -cne 'false') {
    throw 'Die Build-Version braucht die vollstaendige Git-Historie (fetch-depth: 0).'
}

$count = & git -C $root rev-list --first-parent --count HEAD
if ($LASTEXITCODE -ne 0) {
    throw 'Der First-Parent-Zaehler fuer HEAD konnte nicht ermittelt werden.'
}
$code = 0
if ($count -cnotmatch '^[1-9][0-9]*$' -or
    -not [int]::TryParse($count, [ref]$code) -or $code -gt 2100000000) {
    throw 'Der Git-Zaehler muss ein Android-versionCode zwischen 1 und 2100000000 sein.'
}

$projectPath = Join-Path $root 'project.godot'
$presetsPath = Join-Path $root 'export_presets.cfg'
$project = [IO.File]::ReadAllText($projectPath)
$presets = [IO.File]::ReadAllText($presetsPath)

$projectVersion = Find-Setting $project 'application' 'config/version'
$baseVersion = $null
if ($projectVersion.Value -cnotmatch '^"((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))"$' -or
    -not [version]::TryParse($Matches[1], [ref]$baseVersion)) {
    throw 'application/config/version muss eine numerische Version MAJOR.MINOR.PATCH sein.'
}
$name = '{0}.{1}.{2}' -f $baseVersion.Major, $baseVersion.Minor, $code

$androidSections = @(
    foreach ($section in [regex]::Matches($presets, '(?m)^\[(preset\.[0-9]+)\][ \t]*\r?$')) {
        $sectionName = $section.Groups[1].Value
        $platform = Find-Setting $presets $sectionName 'platform'
        if ($platform.Value -ceq '"Android"') {
            $sectionName
        }
    }
)
if ($androidSections.Count -ne 1) {
    throw 'Es muss genau ein Android-Export-Preset vorhanden sein.'
}
$options = "$($androidSections[0]).options"
$oldCode = Find-Setting $presets $options 'version/code'
$previousCode = 0
if ($oldCode.Value -cnotmatch '^[1-9][0-9]*$' -or
    -not [int]::TryParse($oldCode.Value, [ref]$previousCode) -or $previousCode -gt 2100000000) {
    throw 'Das Android-Preset braucht einen version/code zwischen 1 und 2100000000.'
}
if ($code -lt $previousCode) {
    throw "Der Git-Zaehler $code liegt unter dem vorhandenen Android-versionCode $previousCode."
}

# Erst alle Einstellungen validieren und vorbereiten, dann Dateien schreiben.
$newProject = Set-Setting $project 'application' 'config/version' "`"$name`""
$newPresets = Set-Setting $presets $options 'version/name' "`"$name`""
$newPresets = Set-Setting $newPresets $options 'version/code' ([string]$code)
$encoding = [Text.UTF8Encoding]::new($false)
if ($newProject -cne $project) {
    [IO.File]::WriteAllText($projectPath, $newProject, $encoding)
}
if ($newPresets -cne $presets) {
    [IO.File]::WriteAllText($presetsPath, $newPresets, $encoding)
}

[pscustomobject]@{
    VersionName = $name
    VersionCode = $code
    ReleaseTag = $name
}
