[Windows | Oh My Posh](https://ohmyposh.dev/docs/installation/windows#install)

```powershell:powershell
scoop install https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/oh-my-posh.json
```

テーマを変更する場合はPowershellの$Profileに以下を追記
```powershell:$Profile
# mytheme.omp.jsonが存在しない場合はtokyo.omp.jsonをセットする
if (Test-Path -Path "~/.mytheme.omp.json")
{
    oh-my-posh init pwsh --config "~/.mytheme.omp.json" | Invoke-Expression
} else
{
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/tokyo.omp.json" | Invoke-Expression
}
```
