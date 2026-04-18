<#
.SYNOPSIS
    Script to generate images using gpt-image-1.5 (OpenAI or Azure OpenAI).

.DESCRIPTION
    Uses the OpenAI API or Azure OpenAI API (gpt-image-1.5) to generate an image based on a provided prompt.
    The generated image is saved in the 'image' directory.
    Settings are loaded from config.json.

.PARAMETER Prompt
    The text prompt describing the image to generate.

.PARAMETER Size
    The dimensions of the generated image.
    Supported by gpt-image-1.5: '1024x1024', '1024x1536', '1536x1024'.
    If not specified, the default from config.json is used.

.PARAMETER OutputPath
    Full path (absolute or relative to the current working directory) where
    the generated PNG will be written. When supplied, this overrides the
    default "script/image/generated_<timestamp>.png" location. Parent
    directories are created automatically.

.EXAMPLE
    .\generate_image.ps1 -Prompt "A futuristic cityscape" -Size "1536x1024"

.EXAMPLE
    .\generate_image.ps1 -Prompt "..." -Size "1024x1024" -OutputPath "outputs/images/ch01_opener.png"

.NOTES
    FileName:  generate_image.ps1
    Author:    Gemini CLI
    Created:   2026-04-18
    Version:   1.3
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Prompt,

    [Parameter(Mandatory=$false)]
    [ValidateSet('1024x1024', '1024x1536', '1536x1024')]
    [string]$Size,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath
)

# Stop on all errors
$ErrorActionPreference = 'Stop'

# Set default encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

# Logging function
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    switch ($Level) {
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'WARN'  { Write-Host $logEntry -ForegroundColor Yellow }
        'DEBUG' { Write-Host $logEntry -ForegroundColor Gray }
        default { Write-Host $logEntry }
    }
}

try {
    # Load configuration
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path -Path $configPath)) {
        throw "Config file not found: $configPath"
    }
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    Write-Log "Config file loaded successfully."

    $isAzure = $null -ne $config.Azure -and $config.Azure.UseAzure
    $outputDir = Join-Path $PSScriptRoot $config.ImageOutputDir

    if ($isAzure) {
        Write-Log "Mode: Azure OpenAI Service"
        $apiKey = $config.Azure.ApiKey
        $endpoint = $config.Azure.Endpoint
        $headers = @{
            "api-key"      = $apiKey
            "Content-Type" = "application/json"
        }
        $bodyObj = @{
            "prompt"  = $Prompt
            "quality" = $config.DefaultQuality
        }
    } else {
        Write-Log "Mode: OpenAI Official API"
        $apiKey = $config.ApiKey
        $endpoint = $config.Endpoint
        $model = $config.Model
        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type"  = "application/json"
        }
        $bodyObj = @{
            "model"   = $model
            "prompt"  = $Prompt
        }
    }

    # Common parameters
    $targetSize = if (-not [string]::IsNullOrWhiteSpace($Size)) { $Size } else { $config.DefaultSize }
    if (-not [string]::IsNullOrWhiteSpace($targetSize)) { $bodyObj["size"] = $targetSize }
    $bodyObj["response_format"] = "b64_json"

    if ($apiKey -eq "YOUR_API_KEY_HERE" -or $apiKey -eq "YOUR_AZURE_API_KEY_HERE" -or [string]::IsNullOrWhiteSpace($apiKey)) {
        throw "API Key is not configured correctly in config.json."
    }

    $body = $bodyObj | ConvertTo-Json
    Write-Log "Sending request to generate image... (Size: $targetSize)"
    
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body
    }
    catch {
        Write-Log "Error occurred: $($_.Exception.Message)" -Level ERROR
        if ($null -ne $_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Log "API Error Body: $errorBody" -Level ERROR
        }
        throw $_
    }

    if ($null -eq $response.data -or $response.data.Count -eq 0) {
        throw "API response does not contain image data."
    }

    # Handle response data
    $imageData = $response.data[0]

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $filePath = $OutputPath
    }
    else {
        $timestampStr = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "generated_$($timestampStr).png"
        $filePath = Join-Path $outputDir $fileName
    }

    $outputParent = Split-Path -Path $filePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent) -and -not (Test-Path -Path $outputParent)) {
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
        Write-Log "Created output directory: $outputParent"
    }

    if (-not [string]::IsNullOrWhiteSpace($imageData.b64_json)) {
        Write-Log "Saving image from base64 data..."
        $imageBytes = [System.Convert]::FromBase64String($imageData.b64_json)
        [System.IO.File]::WriteAllBytes($filePath, $imageBytes)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($imageData.url)) {
        Write-Log "Downloading image from URL: $($imageData.url)"
        Invoke-WebRequest -Uri $imageData.url -OutFile $filePath
    }
    else {
        throw "Neither b64_json nor url found in API response."
    }

    Write-Log "Image saved successfully: $filePath" -Level INFO
}
catch {
    Write-Log "Error occurred: $($_.Exception.Message)" -Level ERROR
    exit 1
}
finally {
    Write-Log "Process finished."
}
