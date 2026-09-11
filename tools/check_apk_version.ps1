<#
.SYNOPSIS
    Prueft Paketkennung und Version in der Ausgabe von aapt dump badging.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Manifest,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')]
    [string]$VersionName,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2100000000)]
    [int]$VersionCode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packages = @($Manifest | Where-Object { $_ -cmatch '^package:\s' })
if ($packages.Count -ne 1) {
    throw 'Das APK-Manifest muss genau eine package-Zeile enthalten.'
}
$expected = @{
    name = 'de.structed.fourcats'
    versionName = $VersionName
    versionCode = [string]$VersionCode
}
foreach ($key in $expected.Keys) {
    $attributes = [regex]::Matches($packages[0], "(?:^|\s)$key='([^']*)'")
    if ($attributes.Count -ne 1 -or $attributes[0].Groups[1].Value -cne $expected[$key]) {
        throw "APK-Manifest: $key muss '$($expected[$key])' entsprechen."
    }
}
Write-Host "APK-Version: $VersionName (Code $VersionCode), Paket de.structed.fourcats"
