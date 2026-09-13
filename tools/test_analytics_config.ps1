<#
.SYNOPSIS
    Prueft Analytics-Exportkonfiguration mit isolierten Fixtures, ohne Godot,
    Netzwerk, Zugangsdaten oder Testframework. Das echte Projekt bleibt unberuehrt.

.EXAMPLE
    pwsh tools\test_analytics_config.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$configure = Join-Path $PSScriptRoot 'configure_analytics.ps1'
$fixtureRoot = Join-Path (Split-Path $PSScriptRoot -Parent) ".analytics-config-fixtures-$([guid]::NewGuid().ToString('N'))"
$encoding = [Text.UTF8Encoding]::new($false, $true)
$token = 'phc_SyntheticPublicProjectToken123'
$contact = '4cats "Team"\Datenschutz; datenschutz@example.invalid'
$script:assertions = 0
$template = @'
; Projekt: unveraendert, auch [analytics] und " im Kommentar
config_version=5

[application]
config/name="4cats"
config/description="Unverändert"

[analytics] ; Build-Konfiguration
  enabled = false ; Opt-in erst im freigegebenen Build
project_token=""
privacy_contact = "" ; Betreiber
extra="behalten"

[rendering]
renderer/rendering_method="gl_compatibility"
enabled=true
project_token="anderer Abschnitt"
privacy_contact="bleibt stehen"
'@ -replace "`r`n", "`n"

function Assert {
    param([bool]$Condition, [string]$Description)
    if (-not $Condition) { throw "FEHLER: $Description" }
    $script:assertions++
    Write-Host "  [ok] $Description"
}

function New-Fixture {
    param([string]$Name, [string]$Text = $template, [bool]$Bom = $false)
    $root = Join-Path $fixtureRoot $Name
    [IO.Directory]::CreateDirectory($root) | Out-Null
    [IO.File]::WriteAllText((Join-Path $root 'project.godot'), $Text, [Text.UTF8Encoding]::new($Bom, $true))
    $root
}

function Read-Fixture {
    param([string]$Root)
    [IO.File]::ReadAllText((Join-Path $Root 'project.godot'), $encoding)
}

function Assert-Rejected {
    param([string]$Root, [scriptblock]$Action, [string]$Message, [string]$ForbiddenOutput = '')
    $path = Join-Path $Root 'project.godot'
    $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
    $failure = $null
    try { & $Action | Out-Null } catch { $failure = $_ }
    Assert ($null -ne $failure -and $failure.Exception.Message.Contains($Message)) `
        "Ungueltige Eingabe wird abgelehnt: $Message"
    Assert ($before -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))) `
        'Validierungsfehler lassen die Datei bytegenau unveraendert'
    if ($ForbiddenOutput.Length -gt 4) {
        Assert (-not $failure.Exception.Message.Contains($ForbiddenOutput)) `
            'Fehlermeldung gibt keinen Token aus'
    }
    Assert (@(Get-ChildItem -LiteralPath $Root -Filter '*.pending' -Force).Count -eq 0) `
        'Kein unvollstaendiger Schreibvorgang bleibt zurueck'
}

function Read-WorkflowGate {
    param([string]$Name)
    $directory = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) '.github') 'workflows'
    $path = Join-Path $directory "$Name.yml"
    $text = [IO.File]::ReadAllText($path)
    $step = [regex]::Match($text,
        '(?ms)^      - name: Analytics fuer Export konfigurieren\r?\n(?<step>.*?)(?=^      - name:|\z)')
    $run = [regex]::Match($step.Groups['step'].Value, '(?ms)^        run: \|\r?\n(?<code>.*)\z')
    $code = $run.Groups['code'].Value -replace '(?m)^          ', ''
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
    $assignments = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ceq 'enabled'
    }, $true))
    Assert ($run.Success -and $errors.Count -eq 0 -and $assignments.Count -eq 1) `
        "$Name hat eine parsebare, explizite Freigabebedingung"
    # Nur die echte Gate-Zuweisung auswerten, niemals den Export-Konfigurationsaufruf.
    [pscustomobject]@{
        Text = $text
        Step = $step.Groups['step'].Value
        Gate = [scriptblock]::Create($assignments[0].Extent.Text + "`n" + '$enabled')
        ConfigureIndex = $step.Index
    }
}

try {
    Write-Host '--- Deaktivierte und aktivierte Exporte ---'
    $root = New-Fixture 'standard'
    $output = & $configure -ProjectRoot $root
    Assert (-not $output.Enabled -and (Read-Fixture $root) -ceq $template) `
        'Ohne Freigabe bleibt die Default-Konfiguration unveraendert'

    $expected = $template.Replace('enabled = false', 'enabled = true').
        Replace('project_token=""', "project_token=`"$token`"").
        Replace('privacy_contact = ""', 'privacy_contact = "4cats \"Team\"\\Datenschutz; datenschutz@example.invalid"')
    $output = & $configure -Enabled -ProjectToken $token -PrivacyContact $contact -ProjectRoot $root
    Assert ($output.Enabled -and (Read-Fixture $root) -ceq $expected) `
        'Nur drei Werte werden geaendert; Quotes, Backslashes und Semikolon sind korrekt escaped'
    Assert (($output | ConvertTo-Json -Compress) -ceq '{"Enabled":true}') `
        'Erfolgsoutput enthaelt weder Token noch Kontakt'
    & $configure -Enabled -ProjectToken $token -PrivacyContact $contact -ProjectRoot $root | Out-Null
    Assert ((Read-Fixture $root) -ceq $expected) 'Wiederholte Aktivierung ist idempotent'

    $environmentNames = @('ANALYTICS_ENABLED', 'POSTHOG_PROJECT_TOKEN', 'ANALYTICS_PRIVACY_CONTACT')
    $oldEnvironment = @{}
    foreach ($name in $environmentNames) {
        $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    try {
        $env:ANALYTICS_ENABLED = 'true'
        $env:POSTHOG_PROJECT_TOKEN = $token
        $env:ANALYTICS_PRIVACY_CONTACT = $contact
        & $configure -ProjectRoot $root | Out-Null
        Assert ((Read-Fixture $root) -ceq $template) `
            'Umgebungsvariablen aktivieren nichts und vorhandene Token/Kontakte werden geloescht'
        & $configure -Enabled:$false -ProjectToken 'phx_privateKeyMustNotBeUsed' `
            -PrivacyContact "invalid`ncontact" -ProjectRoot $root | Out-Null
        Assert ((Read-Fixture $root) -ceq $template) `
            'Explizit false ignoriert selbst ungueltige mitgegebene Zugangsdaten'
    } finally {
        foreach ($name in $environmentNames) {
            [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name])
        }
    }

    foreach ($case in @(
        @{ Name = 'lf'; Text = $template + "`n"; Bom = $false },
        @{ Name = 'crlf'; Text = $template.Replace("`n", "`r`n") + "`r`n"; Bom = $false },
        @{ Name = 'bom'; Text = $template; Bom = $true }
    )) {
        $root = New-Fixture $case.Name $case.Text $case.Bom
        $path = Join-Path $root 'project.godot'
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
        & $configure -Enabled -ProjectToken $token -PrivacyContact $contact -ProjectRoot $root | Out-Null
        & $configure -ProjectRoot $root | Out-Null
        Assert ($before -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))) `
            "$($case.Name): Zeilenenden, BOM und alle unbeteiligten Inhalte bleiben bytegenau erhalten"
    }

    $description = @'
config/description="Mehrzeilig mit \"Quotes\" und \\Backslash
[analytics]
enabled=false
project_token=\"kein Konfigurationswert\"
privacy_contact=\"ebenfalls Text\"
"
'@ -replace "`r`n", "`n"
    $multiline = $template.Replace('config/description="Unverändert"', $description)
    $root = New-Fixture 'multiline' $multiline
    & $configure -Enabled -ProjectToken $token -PrivacyContact $contact -ProjectRoot $root | Out-Null
    & $configure -ProjectRoot $root | Out-Null
    Assert ((Read-Fixture $root) -ceq $multiline) `
        'Scheinbare Abschnitte und Schluessel in mehrzeiligen Strings werden nicht bearbeitet'

    $quotedKeys = $template.Replace('enabled = false', '"enabled" = false').
        Replace('project_token=""', '"project_token"=""').
        Replace('privacy_contact = ""', '"privacy_contact" = ""')
    $root = New-Fixture 'quoted-keys' $quotedKeys
    & $configure -Enabled -ProjectToken $token -PrivacyContact $contact -ProjectRoot $root | Out-Null
    Assert ((Read-Fixture $root).Contains('"enabled" = true')) 'Godot-Schluessel duerfen quoted sein'
    & $configure -ProjectRoot $root | Out-Null
    Assert ((Read-Fixture $root) -ceq $quotedKeys) 'Quoted-Schluessel bleiben erhalten'

    $root = New-Fixture 'unicode'
    $unicodeContact = '  Datenschutz für München: kontakt@example.invalid ' + [char]::ConvertFromUtf32(0x1F431) + '  '
    & $configure -Enabled -ProjectToken $token -PrivacyContact $unicodeContact -ProjectRoot $root | Out-Null
    Assert ((Read-Fixture $root).Contains('privacy_contact = "' + $unicodeContact.Trim() + '"')) `
        'Druckbares Unicode bleibt erhalten; aeusserer Leerraum im Kontakt wird entfernt'

    $root = New-Fixture 'default-root'
    $fixtureTools = Join-Path $root 'tools'
    [IO.Directory]::CreateDirectory($fixtureTools) | Out-Null
    $fixtureScript = Join-Path $fixtureTools 'configure_analytics.ps1'
    [IO.File]::Copy($configure, $fixtureScript)
    & $fixtureScript -Enabled -ProjectToken $token -PrivacyContact $contact | Out-Null
    Assert ((Read-Fixture $root) -ceq $expected) `
        'Default-ProjectRoot ist das Elternverzeichnis des Skripts, nicht das Arbeitsverzeichnis'

    Write-Host '--- Eingaben und fehlerhafte Projektdateien ---'
    $root = New-Fixture 'invalid-input'
    foreach ($invalid in @('', ' ', 'phc_', 'PHC_abc', 'phx_personalKey', 'secret_adminKey',
        'phc_bad-token', 'phc_quote"token', 'phc_semi;token', "phc_line`nbreak", "phc_end`n")) {
        Assert-Rejected $root {
            & $configure -Enabled -ProjectToken $invalid -PrivacyContact $contact -ProjectRoot $root
        } 'ProjectToken' $invalid
    }
    foreach ($invalid in @('', ' ', "bad`ncontact", "bad`rcontact", "bad`tcontact",
        "bad$([char]0)contact", "bad$([char]0x2028)contact", "bad$([char]0x2029)contact",
        "bad$([char]0x200B)contact", "bad$([char]0xD800)contact")) {
        Assert-Rejected $root {
            & $configure -Enabled -ProjectToken $token -PrivacyContact $invalid -ProjectRoot $root
        } 'PrivacyContact' $token
    }
    Assert-Rejected $root { & $configure -Enabled -ProjectRoot $root } 'ProjectToken'
    Assert-Rejected $root {
        & $configure -Enabled -ProjectToken $token -ProjectRoot $root
    } 'PrivacyContact' $token

    foreach ($key in @('enabled', 'project_token', 'privacy_contact')) {
        $line = switch ($key) {
            'enabled' { '  enabled = false ; Opt-in erst im freigegebenen Build' }
            'project_token' { 'project_token=""' }
            'privacy_contact' { 'privacy_contact = "" ; Betreiber' }
        }
        $root = New-Fixture "missing-$key" $template.Replace($line, '')
        Assert-Rejected $root { & $configure -ProjectRoot $root } "analytics/$key fehlt"
        $root = New-Fixture "duplicate-$key" $template.Replace($line, "$line`n$line")
        Assert-Rejected $root { & $configure -ProjectRoot $root } "analytics/$key ist mehrfach"
    }
    foreach ($case in @(
        @{ Name = 'missing-section'; Text = $template.Replace('[analytics]', '[other]'); Error = '[analytics]-Abschnitt' },
        @{ Name = 'duplicate-section'; Text = $template + "`n[analytics]`n"; Error = '[analytics]-Abschnitt' },
        @{ Name = 'bool-type'; Text = $template.Replace('enabled = false', 'enabled = "false"'); Error = 'analytics/enabled' },
        @{ Name = 'token-type'; Text = $template.Replace('project_token=""', 'project_token=false'); Error = 'analytics/project_token' },
        @{ Name = 'contact-type'; Text = $template.Replace('privacy_contact = ""', 'privacy_contact = 42'); Error = 'analytics/privacy_contact' },
        @{ Name = 'unterminated'; Text = $template + "`nunrelated=`"open"; Error = 'nicht abgeschlossenen String' }
    )) {
        $root = New-Fixture $case.Name $case.Text
        Assert-Rejected $root { & $configure -ProjectRoot $root } $case.Error
    }

    $root = New-Fixture 'invalid-encoding'
    [IO.File]::WriteAllBytes((Join-Path $root 'project.godot'), [byte[]]@(0xFF, 0xFE, 0x61))
    Assert-Rejected $root { & $configure -ProjectRoot $root } 'UTF-8'
    $failure = $null
    try { & $configure -ProjectRoot (Join-Path $fixtureRoot 'missing-root') | Out-Null } catch { $failure = $_ }
    Assert ($null -ne $failure -and $failure.Exception.Message.Contains('project.godot fehlt')) `
        'Ein fehlendes Projekt wird nicht erzeugt'

    Write-Host '--- Workflow-Freigaben (ohne Export oder Zugangsdaten) ---'
    $ci = Read-WorkflowGate 'ci'
    $android = Read-WorkflowGate 'android'
    foreach ($workflow in @($ci, $android)) {
        Assert ($workflow.Step.Contains('ANALYTICS_ENABLED: ${{ vars.ANALYTICS_ENABLED }}')) `
            'Die Analytics-Freigabe bleibt eine Actions-Variable'
        foreach ($name in @('POSTHOG_PROJECT_TOKEN', 'ANALYTICS_PRIVACY_CONTACT')) {
            $mapping = $name + ': ${{ secrets.' + $name + ' }}'
            Assert ($workflow.Step.Contains($mapping) -and -not $workflow.Text.Contains("vars.$name")) `
                "$name wird ausschliesslich aus Actions-Secrets gelesen"
        }
    }
    Assert ($ci.ConfigureIndex -gt $ci.Text.IndexOf('--smoketest') -and
        $ci.ConfigureIndex -lt $ci.Text.IndexOf('--export-release')) `
        'Windows konfiguriert erst nach den Spielpruefungen und vor dem Export'
    Assert ($android.ConfigureIndex -gt $android.Text.IndexOf('--import') -and
        $android.ConfigureIndex -lt $android.Text.IndexOf('--export-release')) `
        'Android konfiguriert erst nach dem Import und vor dem Export'
    Assert ($android.Text.Contains("types: [closed]") -and
        $android.Text.Contains("branches: [main]") -and
        [regex]::Matches($android.Text,
            "if: github\.event\.pull_request\.merged == true && github\.event\.pull_request\.base\.ref == 'main'").Count -eq 2 -and
        $android.Text.Contains('ref: ${{ github.event.pull_request.merge_commit_sha }}') -and
        $android.Text.Contains('persist-credentials: false')) `
        'Android behaelt Closed/Merged-Main-Gates und Merge-SHA-Checkout bei'

    $gateEnvironment = @('ANALYTICS_ENABLED', 'GITHUB_EVENT_NAME', 'GITHUB_REF')
    $previousGateEnvironment = @{}
    foreach ($name in $gateEnvironment) {
        $previousGateEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    try {
        foreach ($flag in @('', 'false', 'true', 'True', 'TRUE', ' true ', '1', 'yes')) {
            $env:ANALYTICS_ENABLED = $flag
            foreach ($context in @(
                @{ Event = 'push'; Ref = 'refs/heads/main'; Trusted = $true },
                @{ Event = 'push'; Ref = 'refs/heads/feature'; Trusted = $false },
                @{ Event = 'pull_request'; Ref = 'refs/pull/1/merge'; Trusted = $false },
                @{ Event = 'pull_request'; Ref = 'refs/heads/main'; Trusted = $false },
                @{ Event = 'pull_request_target'; Ref = 'refs/heads/main'; Trusted = $false },
                @{ Event = 'workflow_dispatch'; Ref = 'refs/heads/main'; Trusted = $false }
            )) {
                $env:GITHUB_EVENT_NAME = $context.Event
                $env:GITHUB_REF = $context.Ref
                $actual = & $ci.Gate
                Assert ($actual -eq ($context.Trusted -and $flag -ceq 'true')) `
                    "Windows: '$flag', $($context.Event), $($context.Ref)"
            }
            Assert ((& $android.Gate) -eq ($flag -ceq 'true')) `
                "Android-Release-Job: nur wortwoertlich true aktiviert ('$flag')"
        }
    } finally {
        foreach ($name in $gateEnvironment) {
            [Environment]::SetEnvironmentVariable($name, $previousGateEnvironment[$name])
        }
    }

    Write-Host "--- $script:assertions Analytics-Konfigurationspruefungen bestanden ---"
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
