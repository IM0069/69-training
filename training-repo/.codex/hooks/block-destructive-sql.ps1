$ErrorActionPreference = "Stop"

$stdin = @($input) -join [Environment]::NewLine

if ([string]::IsNullOrWhiteSpace($stdin) -and [Console]::IsInputRedirected) {
    $stdin = [Console]::In.ReadToEnd()
}

if ([string]::IsNullOrWhiteSpace($stdin)) {
    exit 0
}

try {
    $payload = $stdin | ConvertFrom-Json
} catch {
    exit 0
}

function ConvertTo-SearchText {
    param([Parameter(Position = 0, ValueFromPipeline = $true)] $Value)

    if ($null -eq $Value) {
        return ""
    }

    if ($Value -is [string]) {
        return $Value
    }

    try {
        return ($Value | ConvertTo-Json -Depth 100 -Compress)
    } catch {
        return [string]$Value
    }
}

$text = ConvertTo-SearchText $payload

$hasSqlCommand =
    $text -match '(?i)\bsqlcmd\b' -or
    $text -match '(?i)\bdotnet\s+ef\s+database\s+update\b' -or
    $text -match '(?i)\bInvoke-Sqlcmd\b'

$hasDestructiveSql =
    $text -match '(?is)\bDROP\s+TABLE\b' -or
    $text -match '(?is)\bTRUNCATE\s+TABLE\b' -or
    $text -match '(?is)\bTRUNCATE\s+[^;]+'

if ($hasSqlCommand -and $hasDestructiveSql) {
    [Console]::Error.WriteLine("Blocked by Codex hook: destructive SQL command detected (DROP TABLE / TRUNCATE). Ask for explicit human approval or use a reversible migration/test fixture instead.")
    exit 2
}

exit 0
