Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'

# mytheme.omp.jsonが存在しない場合はtokyo.omp.jsonをセットする
oh-my-posh init pwsh --config "~/.mytheme.omp.json" | Invoke-Expression
if (Test-Path -Path "~/.mytheme.omp.json") {
    oh-my-posh init pwsh --config "~/.mytheme.omp.json" | Invoke-Expression
}
else {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/tokyo.omp.json" | Invoke-Expression
}
