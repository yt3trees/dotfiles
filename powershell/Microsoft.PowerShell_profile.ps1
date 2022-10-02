# Auto Completion
try
{
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Enable-AzPredictor -AllSession
} catch
{
    Write-Warning "PSReadLine not installed."
    Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force -SkipPublisherCheck
    Install-module -name Az.Accounts -AllowClobber
    Install-Module -Name Az.Tools.Predictor
    Install-Module -Name CompletionPredictor
}

# Tig
Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'

# mytheme.omp.jsonが存在しない場合はtokyo.omp.jsonをセットする
if (Test-Path -Path "~/.mytheme.omp.json")
{
    oh-my-posh init pwsh --config "~/.mytheme.omp.json" | Invoke-Expression
} else
{
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/tokyo.omp.json" | Invoke-Expression
}
