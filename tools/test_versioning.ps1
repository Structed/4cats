<#
.SYNOPSIS
    Prueft Build-Versionen mit temporaeren Git-Repositories, ohne Testframework.

.EXAMPLE
    pwsh tools/test_versioning.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$setVersion = Join-Path $PSScriptRoot 'set_build_version.ps1'
$checkApkVersion = Join-Path $PSScriptRoot 'check_apk_version.ps1'
$gitExecutable = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$fixtureRoot = [IO.Directory]::CreateTempSubdirectory('4cats-versioning-').FullName
$emptyHooks = Join-Path $fixtureRoot 'hooks'
[IO.Directory]::CreateDirectory($emptyHooks) | Out-Null
$encoding = [Text.UTF8Encoding]::new($false)

$projectTemplate = @'
; Projekt
[application]
config/name="4cats"
config/version="0.1.0"

[rendering]
renderer/rendering_method="gl_compatibility"
'@ -replace "`r`n", "`n"
$presetsTemplate = @'
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"

[preset.0.options]
version/name="leave-windows-alone"
version/code=88

[preset.7]
name="Android"
platform="Android"

[preset.7.options]
version/name="0.1.0"
version/code=1
package/unique_name="de.structed.fourcats"
package/signed=true
'@ -replace "`r`n", "`n"

function Assert {
    param([bool]$Condition, [string]$Description)
    if (-not $Condition) { throw "FEHLER: $Description" }
    Write-Host "  [ok] $Description"
}

function Invoke-TestGit {
    param([string]$Root, [string[]]$Arguments)
    $output = & $gitExecutable -C $Root `
        -c user.name=VersioningTest -c user.email=versioning@example.invalid `
        -c commit.gpgsign=false -c core.autocrlf=false -c "core.hooksPath=$emptyHooks" `
        @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' '): $output" }
}

function Reset-Fixture {
    param([string]$Root)
    [IO.File]::WriteAllText((Join-Path $Root 'project.godot'), $projectTemplate, $encoding)
    [IO.File]::WriteAllText((Join-Path $Root 'export_presets.cfg'), $presetsTemplate, $encoding)
}

function New-TestCommit {
    param([string]$Root, [string]$Message)
    Invoke-TestGit $Root @('commit', '--quiet', '--allow-empty', '-m', $Message, '-m',
        'Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>')
}

function New-TestRepository {
    param([string]$Name)
    $root = Join-Path $fixtureRoot $Name
    [IO.Directory]::CreateDirectory($root) | Out-Null
    Reset-Fixture $root
    Invoke-TestGit $root @('init', '--quiet', '--initial-branch=main')
    Invoke-TestGit $root @('add', '.')
    New-TestCommit $root 'initial'
    $root
}

function Add-TestChange {
    param([string]$Root, [string]$File, [string]$Value)
    [IO.File]::WriteAllText((Join-Path $Root $File), $Value, $encoding)
    Invoke-TestGit $Root @('add', $File)
    New-TestCommit $Root "$File $Value"
}

function Assert-Version {
    param([string]$Root, [int]$Code)
    $version = & $setVersion -ProjectRoot $Root
    Assert ($version.VersionName -ceq "0.1.$Code" -and $version.VersionCode -eq $Code -and
        $version.ReleaseTag -ceq $version.VersionName) "Version und Tag 0.1.$Code, Code $Code"
    $project = [IO.File]::ReadAllText((Join-Path $Root 'project.godot'))
    $presets = [IO.File]::ReadAllText((Join-Path $Root 'export_presets.cfg'))
    Assert ($project -ceq $projectTemplate.Replace('"0.1.0"', "`"0.1.$Code`"")) `
        'Nur die Projektversion wird ersetzt'
    Assert ($presets -ceq $presetsTemplate.Replace('"0.1.0"', "`"0.1.$Code`"").
        Replace('version/code=1', "version/code=$Code")) `
        'Nur die Version im Android-Preset wird ersetzt'
}

function Assert-Rejected {
    param([string]$Root, [scriptblock]$Action, [string]$Message)
    $projectPath = Join-Path $Root 'project.godot'
    $presetsPath = Join-Path $Root 'export_presets.cfg'
    $beforeProject = [IO.File]::ReadAllText($projectPath)
    $beforePresets = [IO.File]::ReadAllText($presetsPath)
    $failure = $null
    try { & $Action | Out-Null } catch { $failure = $_ }
    Assert ($null -ne $failure -and $failure.Exception.Message.Contains($Message)) `
        "Ungueltige Eingabe wird abgelehnt: $Message"
    Assert ($beforeProject -ceq [IO.File]::ReadAllText($projectPath) -and
        $beforePresets -ceq [IO.File]::ReadAllText($presetsPath)) 'Fehler veraendern keine Dateien'
}

function Invoke-VersionWithCount {
    param([string]$Root, [string]$FakeCount)
    # Nur den unpraktisch grossen Git-Zaehler simulieren, nicht die Versionierung.
    function git {
        if ($args -contains 'rev-list') { return $FakeCount }
        & $gitExecutable @args
    }
    & $setVersion -ProjectRoot $Root
}

try {
    Write-Host '--- Build-Versionen ---'
    $linear = New-TestRepository 'linear'
    for ($i = 2; $i -le 9; $i++) { New-TestCommit $linear "commit $i" }
    Assert-Version $linear 9
    Assert-Version $linear 9
    New-TestCommit $linear 'commit 10'
    Assert-Version $linear 10
    Assert ([version]'0.1.10' -gt [version]'0.1.9') 'Versionsfolge bleibt nach 9 numerisch'
    Invoke-TestGit $linear @('switch', '--quiet', '--detach', 'HEAD~1')
    Reset-Fixture $linear
    Assert-Version $linear 9
    Invoke-TestGit $linear @('switch', '--quiet', 'main')
    Assert-Version $linear 10

    Write-Host '--- PR-Reihenfolge und Merge-Arten ---'
    $merges = New-TestRepository 'merges'
    Invoke-TestGit $merges @('switch', '--quiet', '-c', 'pr-1')
    Add-TestChange $merges 'older.txt' '1'
    Add-TestChange $merges 'older.txt' '2'
    Invoke-TestGit $merges @('switch', '--quiet', 'main')
    Invoke-TestGit $merges @('switch', '--quiet', '-c', 'pr-20')
    Add-TestChange $merges 'newer.txt' '1'
    Invoke-TestGit $merges @('switch', '--quiet', 'main')
    Invoke-TestGit $merges @('merge', '--no-ff', '--no-commit', 'pr-20')
    New-TestCommit $merges 'Merge PR 20 before PR 1'
    Assert-Version $merges 2
    Invoke-TestGit $merges @('merge', '--no-ff', '--no-commit', 'pr-1')
    New-TestCommit $merges 'Merge PR 1 after PR 20'
    Assert-Version $merges 3

    $squash = New-TestRepository 'squash'
    Invoke-TestGit $squash @('switch', '--quiet', '-c', 'feature')
    Add-TestChange $squash 'feature.txt' '1'
    Add-TestChange $squash 'feature.txt' '2'
    Invoke-TestGit $squash @('switch', '--quiet', 'main')
    Invoke-TestGit $squash @('merge', '--squash', 'feature')
    New-TestCommit $squash 'Squash feature'
    Assert-Version $squash 2

    $rebase = New-TestRepository 'rebase'
    Invoke-TestGit $rebase @('switch', '--quiet', '-c', 'feature')
    Add-TestChange $rebase 'feature.txt' '1'
    Add-TestChange $rebase 'feature.txt' '2'
    Invoke-TestGit $rebase @('switch', '--quiet', 'main')
    Add-TestChange $rebase 'main.txt' '1'
    Invoke-TestGit $rebase @('rebase', 'main', 'feature')
    Invoke-TestGit $rebase @('switch', '--quiet', 'main')
    Invoke-TestGit $rebase @('merge', '--ff-only', 'feature')
    Assert-Version $rebase 4

    Write-Host '--- Konfiguration und Grenzen ---'
    Reset-Fixture $linear
    $projectPath = Join-Path $linear 'project.godot'
    $presetsPath = Join-Path $linear 'export_presets.cfg'
    [IO.File]::WriteAllText($projectPath, $projectTemplate.Replace('"0.1.0"', '"1.2.0"'), $encoding)
    $version = & $setVersion -ProjectRoot $linear
    Assert ($version.VersionName -ceq '1.2.10' -and $version.VersionCode -eq 10) `
        'Neue Versionsreihe setzt den Android-Code nicht zurueck'

    Reset-Fixture $linear
    [IO.File]::WriteAllText($projectPath, $projectTemplate.Replace("`n", "`r`n"), $encoding)
    [IO.File]::WriteAllText($presetsPath, $presetsTemplate.Replace("`n", "`r`n"), $encoding)
    & $setVersion -ProjectRoot $linear | Out-Null
    Assert ([IO.File]::ReadAllText($projectPath) -ceq
        $projectTemplate.Replace('"0.1.0"', '"0.1.10"').Replace("`n", "`r`n") -and
        [IO.File]::ReadAllText($presetsPath) -ceq $presetsTemplate.
        Replace('"0.1.0"', '"0.1.10"').Replace('version/code=1', 'version/code=10').Replace("`n", "`r`n")) `
        'CRLF-Zeilenenden bleiben erhalten'

    foreach ($invalid in @('1.2', '01.2.3', '1.2.3-beta', '1.2.3+4', '2147483648.0.0')) {
        Reset-Fixture $linear
        [IO.File]::WriteAllText($projectPath, $projectTemplate.Replace('0.1.0', $invalid), $encoding)
        Assert-Rejected $linear { & $setVersion -ProjectRoot $linear } 'MAJOR.MINOR.PATCH'
    }
    foreach ($invalid in @('0', '-1', '2100000001', '2147483648')) {
        Reset-Fixture $linear
        [IO.File]::WriteAllText($presetsPath, $presetsTemplate.Replace('version/code=1',
            "version/code=$invalid"), $encoding)
        Assert-Rejected $linear { & $setVersion -ProjectRoot $linear } 'zwischen 1 und 2100000000'
    }
    Reset-Fixture $linear
    [IO.File]::WriteAllText($presetsPath, $presetsTemplate.Replace('version/code=1', 'version/code=11'), $encoding)
    Assert-Rejected $linear { & $setVersion -ProjectRoot $linear } 'unter dem vorhandenen'

    Reset-Fixture $linear
    [IO.File]::WriteAllText($presetsPath, $presetsTemplate.Replace('version/name="0.1.0"', ''), $encoding)
    Assert-Rejected $linear { & $setVersion -ProjectRoot $linear } 'version/name fehlt'
    Reset-Fixture $linear
    [IO.File]::WriteAllText($projectPath, $projectTemplate.Replace('config/version="0.1.0"',
        "config/version=`"0.1.0`"`nconfig/version=`"0.1.0`""), $encoding)
    Assert-Rejected $linear { & $setVersion -ProjectRoot $linear } 'config/version fehlt oder ist mehrfach'
    Reset-Fixture $linear
    [IO.File]::WriteAllText($presetsPath, $presetsTemplate.Replace('platform="Windows Desktop"',
        'platform="Android"'), $encoding)
    Assert-Rejected $linear { & $setVersion -ProjectRoot $linear } 'genau ein Android-Export-Preset'

    Reset-Fixture $linear
    $version = Invoke-VersionWithCount $linear '2100000000'
    Assert ($version.VersionCode -eq 2100000000 -and $version.VersionName -ceq '0.1.2100000000') `
        'Android-Obergrenze ist erlaubt'
    foreach ($invalid in @('0', '-1', '2100000001', '2147483648', 'keine-zahl')) {
        Reset-Fixture $linear
        Assert-Rejected $linear { Invoke-VersionWithCount $linear $invalid } 'zwischen 1 und 2100000000'
    }

    Reset-Fixture $linear
    $shallow = Join-Path $fixtureRoot 'shallow'
    $linearUri = [UriBuilder]::new('file', '', -1, $linear).Uri.AbsoluteUri
    Invoke-TestGit $fixtureRoot @('clone', '--quiet', '--depth=1', $linearUri, $shallow)
    Assert-Rejected $shallow { & $setVersion -ProjectRoot $shallow } 'vollstaendige Git-Historie'

    Write-Host '--- APK-Metadaten ---'
    $package = "package: name='de.structed.fourcats' versionCode='12' versionName='0.1.12' platformBuildVersionName='15'"
    & $checkApkVersion -Manifest @($package, "application-label:'4cats'") -VersionName '0.1.12' -VersionCode 12
    & $checkApkVersion -Manifest "package: versionName='0.1.12' name='de.structed.fourcats' versionCode='12'" `
        -VersionName '0.1.12' -VersionCode 12
    foreach ($invalidManifest in @(
        $package.Replace('de.structed.fourcats', 'de.structed.other'),
        $package.Replace("versionCode='12'", "versionCode='1'"),
        $package.Replace("versionName='0.1.12'", "versionName='0.1.0'"),
        $package.Replace(" versionName='0.1.12'", ''),
        "$package versionCode='12'",
        "application-label:'4cats'"
    )) {
        Assert-Rejected $linear {
            & $checkApkVersion -Manifest $invalidManifest -VersionName '0.1.12' -VersionCode 12
        } 'APK-Manifest'
    }
    Assert-Rejected $linear {
        & $checkApkVersion -Manifest @($package, $package) -VersionName '0.1.12' -VersionCode 12
    } 'genau eine package-Zeile'

    Write-Host 'Alle Versionspruefungen bestanden.'
} finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
