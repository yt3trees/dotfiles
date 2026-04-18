<#
.SYNOPSIS
    Check whether config.json has a valid API key configured for image generation.

.DESCRIPTION
    Reads config.json next to this script and determines whether the image
    generation pipeline (generate_image.ps1) is usable.

    Outputs a single line to stdout in one of the following forms:
      CONFIGURED: OpenAI
      CONFIGURED: Azure
      NOT_CONFIGURED: <reason>

    Exit codes:
      0 = configured (ready to generate images)
      1 = not configured (fall back to prompt placeholders)
      2 = config.json missing or unreadable

.EXAMPLE
    .\check_config.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

$placeholders = @(
    'YOUR_API_KEY_HERE',
    'YOUR_AZURE_API_KEY_HERE',
    'sk-xxxxxxxx',
    ''
)

function Test-KeyConfigured {
    param([string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return $false }
    foreach ($p in $placeholders) {
        if ($Key -eq $p) { return $false }
    }
    return $true
}

try {
    $configPath = Join-Path $PSScriptRoot 'config.json'
    if (-not (Test-Path -Path $configPath)) {
        Write-Output "NOT_CONFIGURED: config.json not found at $configPath"
        exit 2
    }

    try {
        $config = Get-Content -Path $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Output "NOT_CONFIGURED: failed to parse config.json ($($_.Exception.Message))"
        exit 2
    }

    $useAzure = $false
    if ($null -ne $config.Azure -and $null -ne $config.Azure.UseAzure) {
        $useAzure = [bool]$config.Azure.UseAzure
    }

    if ($useAzure) {
        $azureKey = $config.Azure.ApiKey
        $azureEndpoint = $config.Azure.Endpoint
        if (-not (Test-KeyConfigured $azureKey)) {
            Write-Output "NOT_CONFIGURED: Azure.ApiKey is placeholder or empty"
            exit 1
        }
        if ([string]::IsNullOrWhiteSpace($azureEndpoint) -or $azureEndpoint -match '\{resource-name\}|\{deployment-id\}') {
            Write-Output "NOT_CONFIGURED: Azure.Endpoint still contains placeholder tokens"
            exit 1
        }
        Write-Output "CONFIGURED: Azure"
        exit 0
    }
    else {
        $apiKey = $config.ApiKey
        if (-not (Test-KeyConfigured $apiKey)) {
            Write-Output "NOT_CONFIGURED: ApiKey is placeholder or empty"
            exit 1
        }
        Write-Output "CONFIGURED: OpenAI"
        exit 0
    }
}
catch {
    Write-Output "NOT_CONFIGURED: unexpected error ($($_.Exception.Message))"
    exit 2
}
