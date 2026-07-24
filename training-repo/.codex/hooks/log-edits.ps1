$ErrorActionPreference = "Stop"

$stdin = @($input) -join [Environment]::NewLine

if ([string]::IsNullOrWhiteSpace($stdin) -and [Console]::IsInputRedirected) {
    $stdin = [Console]::In.ReadToEnd()
}
$hookDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath = Join-Path $hookDir "edit-log.txt"

$toolName = "apply_patch"
$files = New-Object System.Collections.Generic.List[string]

function Add-PatchFiles {
    param([Parameter(Position = 0)] [string] $PatchText)

    if ([string]::IsNullOrWhiteSpace($PatchText)) {
        return
    }

    $patterns = @(
        '^\*\*\* Add File:\s+(.+)$',
        '^\*\*\* Update File:\s+(.+)$',
        '^\*\*\* Delete File:\s+(.+)$',
        '^\*\*\* Move to:\s+(.+)$'
    )

    foreach ($line in ($PatchText -split '\r?\n')) {
        foreach ($pattern in $patterns) {
            $match = [regex]::Match($line, $pattern)
            if ($match.Success) {
                $files.Add($match.Groups[1].Value.Trim())
            }
        }
    }
}

try {
    if (-not [string]::IsNullOrWhiteSpace($stdin)) {
        $payload = $stdin | ConvertFrom-Json

        if ($payload.tool_name) {
            $toolName = [string]$payload.tool_name
        } elseif ($payload.toolName) {
            $toolName = [string]$payload.toolName
        }

        $jsonText = $payload | ConvertTo-Json -Depth 100
        Add-PatchFiles $jsonText

        if ($payload.tool_input) {
            Add-PatchFiles ([string]$payload.tool_input)
            Add-PatchFiles ($payload.tool_input | ConvertTo-Json -Depth 100)
        }
        if ($payload.toolInput) {
            Add-PatchFiles ([string]$payload.toolInput)
            Add-PatchFiles ($payload.toolInput | ConvertTo-Json -Depth 100)
        }
        if ($payload.input) {
            Add-PatchFiles ([string]$payload.input)
            Add-PatchFiles ($payload.input | ConvertTo-Json -Depth 100)
        }
    }
} catch {
    $files.Add("(unable to parse hook payload)")
}

if ($files.Count -eq 0) {
    $files.Add("(no file path detected)")
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$uniqueFiles = $files | Select-Object -Unique

foreach ($file in $uniqueFiles) {
    Add-Content -Path $logPath -Value "$timestamp`t$toolName`t$file" -Encoding UTF8
}

$message = "Logged file edit: " + (($uniqueFiles | Select-Object -First 5) -join ", ")
if ($uniqueFiles.Count -gt 5) {
    $message += " ..."
}

@{
    systemMessage = $message
} | ConvertTo-Json -Compress

exit 0
