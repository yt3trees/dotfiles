$scriptPath = 'C:\Users\ytmori\.claude\hooks\cc-toast.ps1'
$content = [System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8)
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($scriptPath, $content, $utf8Bom)
Write-Host "Converted to UTF-8 with BOM"
