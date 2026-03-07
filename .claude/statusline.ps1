# UTF-8 エンコーディング設定(BOMなし)
chcp 65001 | Out-Null
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# ==========================================
# 0. ANSI カラー定義
# ==========================================
$e = [char]0x1b
$RESET   = "$e[0m"
$BOLD    = "$e[1m"
$RED     = "$e[31m"
$GREEN   = "$e[32m"
$YELLOW  = "$e[33m"
$BLUE    = "$e[34m"
$MAGENTA = "$e[35m"
$CYAN    = "$e[36m"
$GRAY    = "$e[90m"    # Dark Gray
$WHITE   = "$e[97m"    # Bright White

# ==========================================
# ★ Nerd Font アイコン定義
# ==========================================
$nfBranch    = [char]0xe0a0 + " "
$nfClock     = [char]0xf017 + " "
$nfHourglass = [char]0xf252 + " "
$nfCheck     = [char]0xf00c + " "
$nfWarn      = [char]0xf071 + " "

# Gitステータス用（通常の記号）
$symPlus      = "+"
$symExclam    = "!"
$symQuest     = "?"

# ==========================================
# ★ デザイン・配色設定
# ==========================================
$ColModel    = $CYAN
$ColPlan     = $GRAY
$Sep         = " $GRAY|$RESET "

# パスの色
$ColPathText   = $RESET

# お金の色
$ColMoneyText  = $WHITE

# --- Git 配色 ---
$ColGit      = $BLUE

# Gitステータス色
$ColStaged    = $GREEN
$ColModified  = $YELLOW
$ColUntracked = $GRAY

# ==========================================
# 1. プランと上限設定
# ==========================================
$plan = "FREE"
$costLimit = 4.00

$credFile = Join-Path $env:USERPROFILE ".claude\.credentials.json"
if ($env:ANTHROPIC_API_KEY) { $plan = "API" }
elseif (Test-Path $credFile) {
    try {
        $cred = Get-Content $credFile -Raw | ConvertFrom-Json
        if ($cred.claudeAiOauth -and $cred.claudeAiOauth.subscriptionType) {
            $plan = $cred.claudeAiOauth.subscriptionType.ToUpper()
        }
    } catch {}
}

switch ($plan) {
    "PRO" { $costLimit = 4.00 }
    "MAX" { $costLimit = 25.00 }
    "API" { $costLimit = 10.00 }
    Default { $costLimit = 5.00 }
}

# プラン表示
$planDisplay = if ($plan) { "$Sep$ColPlan$plan$RESET" } else { "" }

# ==========================================
# 2. データ取得 & 基本計算
# ==========================================
try {
    if ([Console]::IsInputRedirected) {
        $inputJson = [Console]::In.ReadToEnd()
        $stdData = $inputJson | ConvertFrom-Json
    } else {
        $stdData = @{ model = @{ display_name = "-" }; workspace = @{ current_dir = $PWD.Path } }
    }
} catch {
    $stdData = @{ model = @{ display_name = "Err" } }
}

$modelName = if ($stdData.model.display_name) { $stdData.model.display_name } else { "Unknown" }
$contextSize = if ($stdData.context_window.context_window_size) { [int]$stdData.context_window.context_window_size } else { 200000 }
$currentDir = if ($stdData.workspace.current_dir) { $stdData.workspace.current_dir } else { "" }
$transcriptPath = if ($stdData.transcript_path) { $stdData.transcript_path } else { "" }

$percentage = if ($null -ne $stdData.context_window.used_percentage) { [int]$stdData.context_window.used_percentage } else { 0 }
$totalUsed = [math]::Round($contextSize * $percentage / 100)
$usedK = [math]::Round($totalUsed / 1000, 1)

# コンテキストバー
$ctxColor = $GREEN
if ($percentage -ge 80) { $ctxColor = $RED }
elseif ($percentage -ge 50) { $ctxColor = $YELLOW }

$ctxBarCount = [math]::Min([math]::Floor($percentage / 10), 10)
$ctxFilled = ([char]0x25B0).ToString() * $ctxBarCount
$ctxEmpty = ([char]0x25B1).ToString() * (10 - $ctxBarCount)

$contextBar = "$ctxColor$ctxFilled$GRAY$ctxEmpty$RESET"

# ==========================================
# 3. ccusage データ取得 (改善版)
# ==========================================
$ccData = $null
$cacheFile = Join-Path $env:TEMP "claude_ccusage_cache.json"
$cacheDurationMinutes = 3

# キャッシュから読み込み
if (Test-Path $cacheFile) {
    try {
        $rawContent = Get-Content $cacheFile -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($rawContent)) { 
            $ccData = $rawContent | ConvertFrom-Json 
        }
    } catch {
        # キャッシュが壊れている場合は削除
        Remove-Item $cacheFile -ErrorAction SilentlyContinue
    }
}

# キャッシュ更新判定
$shouldUpdate = $true
if ($ccData -and (Test-Path $cacheFile)) {
    $lastWrite = (Get-Item $cacheFile).LastWriteTime
    if ((Get-Date) -lt $lastWrite.AddMinutes($cacheDurationMinutes)) { 
        $shouldUpdate = $false 
    }
}

# ccusageから新しいデータを取得
if ($shouldUpdate) {
    if (Get-Command "npx" -ErrorAction SilentlyContinue) {
        try {
            # 出力を直接キャプチャ
            $rawOutput = & npx --yes ccusage@latest blocks --active --json 2>&1
            
            # 文字列として結合
            $outputStr = $rawOutput -join "`n"
            
            # JSONを抽出（最初の{から最後の}まで）
            if ($outputStr -match '(\{[\s\S]*"blocks"[\s\S]*\})') {
                $jsonPart = $matches[1]
                $newData = $jsonPart | ConvertFrom-Json
                
                # データが有効ならキャッシュに保存
                if ($newData -and $newData.blocks -and $newData.blocks.Count -gt 0) {
                    $jsonPart | Set-Content -Path $cacheFile -Encoding UTF8
                    $ccData = $newData
                }
            }
        } catch {
            # エラー時はキャッシュを維持（削除しない）
        }
    }
}

# ==========================================
# 4. 詳細情報の計算
# ==========================================
$resetInfo = ""
$costInfo = ""
$foundResetTime = $false

if ($ccData -and $ccData.blocks) {
    # アクティブなブロックを優先、なければ最初のブロック
    $block = $ccData.blocks | Where-Object { $_.isActive -eq $true } | Select-Object -First 1
    if (-not $block) { $block = $ccData.blocks | Select-Object -First 1 }

    if ($block) {
        # リセット時間の処理
        if ($block.endTime) {
            try {
                $endTimeStrRaw = $block.endTime
                $endTime = [DateTime]::Parse($endTimeStrRaw)
                if ($endTime.Kind -ne 'Local') { $endTime = $endTime.ToLocalTime() }

                $now = Get-Date
                $diff = $endTime - $now
                $endTimeDisp = $endTime.ToString("HH:mm")

                $timeIcon = $nfCheck
                $timeText = "$endTimeDisp$RESET"
                
                if ($diff.TotalSeconds -gt 0) {
                    $h = [math]::Floor($diff.TotalHours)
                    $m = $diff.Minutes
                    $timeIcon = $nfHourglass
                    $timeText = "${ColPlan}${h}h ${m}m$RESET ($endTimeDisp)"
                }
                
                $resetInfo = "$Sep$timeIcon$timeText"
                $foundResetTime = $true
            } catch {
                # 時間のパースに失敗した場合は何もしない
            }
        }

        # コストバーの処理
        if ($block.costUSD) {
            try {
                $cost = [double]$block.costUSD
                $costDisp = [math]::Round($cost, 2)
                $costPct = ($cost / $costLimit) * 100

                $cColor = $GREEN
                if ($costPct -ge 100) { $cColor = $RED }
                elseif ($costPct -ge 80) { $cColor = $YELLOW }

                $displayPct = [math]::Min($costPct, 100)
                $limitBarCount = [math]::Min([math]::Floor($displayPct / 10), 10)

                $cFilled = ([char]0x2593).ToString() * $limitBarCount 
                $cEmpty = ([char]0x2591).ToString() * (10 - $limitBarCount)

                $warn = ""
                if ($costPct -ge 100) { $warn = " $RED!$RESET" }
                elseif ($costPct -ge 80) { $warn = " $YELLOW*$RESET" }

                $costInfo = "$Sep$cColor$cFilled$GRAY$cEmpty$RESET ${ColMoneyText}`$$costDisp$RESET$warn"
            } catch {
                # コストの計算に失敗した場合は何もしない
            }
        }
    }
}

# フォールバック: ccusageからデータが取得できなかった場合のみ
if (-not $foundResetTime) {
    if ($percentage -eq 0) {
        $resetInfo = "$Sep${GREEN}New Session$RESET"
    } else {
        # ccusageが利用できない旨を表示
        $resetInfo = "$Sep${GRAY}ccusage N/A$RESET"
    }
}

# ==========================================
# 4.5. 5h レート制限 (APIヘッダー, キャッシュ360秒)
# ==========================================
$rlCacheFile = Join-Path $env:TEMP "claude_rl_5h_cache.json"
$rlCacheTTL  = 360
$rlData      = $null
$rlShouldFetch = $true

if (Test-Path $rlCacheFile) {
    try {
        $rlData = Get-Content $rlCacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($rlData -and $rlData.five_hour_util) {
            $rlAge = ((Get-Date) - (Get-Item $rlCacheFile).LastWriteTime).TotalSeconds
            if ($rlAge -lt $rlCacheTTL) { $rlShouldFetch = $false }
        }
    } catch {}
}

if ($rlShouldFetch) {
    $rlToken = $null
    try {
        if (Test-Path $credFile) {
            $rlCred  = Get-Content $credFile -Raw | ConvertFrom-Json
            $rlToken = $rlCred.claudeAiOauth.accessToken
        }
    } catch {}

    if ($rlToken) {
        try {
            $rlBodyFile = Join-Path $env:TEMP "claude_rl_body.json"
            [System.IO.File]::WriteAllText($rlBodyFile, '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"h"}]}')
            $rlRaw  = & curl.exe -sD- -o NUL --max-time 8 `
                -H "Authorization: Bearer $rlToken" `
                -H "Content-Type: application/json" `
                -H "anthropic-beta: oauth-2025-04-20" `
                -H "anthropic-version: 2023-06-01" `
                --data-binary "@$rlBodyFile" `
                "https://api.anthropic.com/v1/messages" 2>$null

            $rlStr  = $rlRaw -join "`n"
            $h5uM   = [regex]::Match($rlStr, '(?i)anthropic-ratelimit-unified-5h-utilization:\s*(\S+)')
            $h5rM   = [regex]::Match($rlStr, '(?i)anthropic-ratelimit-unified-5h-reset:\s*(\S+)')
            $h7uM   = [regex]::Match($rlStr, '(?i)anthropic-ratelimit-unified-7d-utilization:\s*(\S+)')
            $h7rM   = [regex]::Match($rlStr, '(?i)anthropic-ratelimit-unified-7d-reset:\s*(\S+)')
            $h5u    = if ($h5uM.Success) { $h5uM.Groups[1].Value.Trim() } else { $null }
            $h5r    = if ($h5rM.Success) { $h5rM.Groups[1].Value.Trim() } else { $null }
            $h7u    = if ($h7uM.Success) { $h7uM.Groups[1].Value.Trim() } else { $null }
            $h7r    = if ($h7rM.Success) { $h7rM.Groups[1].Value.Trim() } else { $null }

            if ($h5u) {
                @{ five_hour_util = $h5u; five_hour_reset = $h5r; seven_day_util = $h7u; seven_day_reset = $h7r } |
                    ConvertTo-Json | Set-Content $rlCacheFile -Encoding UTF8
                $rlData = @{ five_hour_util = $h5u; five_hour_reset = $h5r; seven_day_util = $h7u; seven_day_reset = $h7r }
            }
        } catch {}
    }
}

# キャッシュ取得失敗時も古いキャッシュを使う
if (-not $rlData -and (Test-Path $rlCacheFile)) {
    try { $rlData = Get-Content $rlCacheFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

$fiveHourInline = ""
if ($rlData -and $rlData.five_hour_util) {
    try {
        $f5Pct   = [int]([double]$rlData.five_hour_util * 100)
        $f5Color = if ($f5Pct -ge 80) { $RED } elseif ($f5Pct -ge 50) { $YELLOW } else { $GREEN }

        $f5Count  = [math]::Min([math]::Floor($f5Pct / 10), 10)
        $f5Fill   = ([char]0x25B0).ToString() * $f5Count
        $f5Empty  = ([char]0x25B1).ToString() * (10 - $f5Count)

        $f5Reset = ""
        if ($rlData.five_hour_reset) {
            $epoch   = [long]$rlData.five_hour_reset
            $resetDt = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
            $f5Reset = " ${GRAY}Resets $($resetDt.ToString('HH:mm'))$RESET"
        }

        $fiveLine = "${GRAY}[5h]${RESET} ${f5Color}${f5Fill}${GRAY}${f5Empty}${RESET} ${f5Color}${f5Pct}%${RESET}${f5Reset}"
    } catch {}
}

$sevenDayLine = ""
if ($rlData -and $rlData.seven_day_util) {
    try {
        $f7Pct   = [int]([double]$rlData.seven_day_util * 100)
        $f7Color = if ($f7Pct -ge 80) { $RED } elseif ($f7Pct -ge 50) { $YELLOW } else { $GREEN }

        $f7Count  = [math]::Min([math]::Floor($f7Pct / 10), 10)
        $f7Fill   = ([char]0x25B0).ToString() * $f7Count
        $f7Empty  = ([char]0x25B1).ToString() * (10 - $f7Count)

        $f7Reset = ""
        if ($rlData.seven_day_reset) {
            $epoch   = [long]$rlData.seven_day_reset
            $resetDt = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
            $f7Reset = " ${GRAY}Resets $($resetDt.ToString('M/d HH:mm'))$RESET"
        }

        $sevenDayLine = "${GRAY}[7d]${RESET} ${f7Color}${f7Fill}${GRAY}${f7Empty}${RESET} ${f7Color}${f7Pct}%${RESET}${f7Reset}"
    } catch {}
}

# ==========================================
# 5. 出力
# ==========================================
$lowTokenWarning = ""
if ($percentage -ge 80) { $lowTokenWarning = "$Sep$RED$nfWarn Low tokens$RESET" }

# Git情報 (Line 1 で使うため先に計算)
$gitInfo = ""
if ($currentDir -and (Test-Path $currentDir)) {
    try {
        Push-Location $currentDir
        git rev-parse --git-dir 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null

            $cntStaged    = 0
            $cntModified  = 0
            $cntUntracked = 0
            $statusLines = @(git status --porcelain 2>$null)

            foreach ($line in $statusLines) {
                if ([string]::IsNullOrEmpty($line) -or $line.Length -lt 2) { continue }
                $idx = $line.Substring(0, 1)
                $wt  = $line.Substring(1, 1)
                if ($idx -eq '?') { $cntUntracked++; continue }
                if ($idx -ne ' ') { $cntStaged++ }
                if ($wt -ne ' ') { $cntModified++ }
            }

            $gitStats = ""
            if ($cntStaged -gt 0)    { $gitStats += " $ColStaged$symPlus$cntStaged$RESET" }
            if ($cntModified -gt 0)  { $gitStats += " $ColModified$symExclam$cntModified$RESET" }
            if ($cntUntracked -gt 0) { $gitStats += " $ColUntracked$symQuest$cntUntracked$RESET" }
            if ($gitStats -eq "" -and $statusLines.Count -gt 0) {
                $gitStats = " $ColUntracked$symQuest$RESET"
            }

            $gitInfo = "$Sep$ColGit$nfBranch$branch$gitStats$RESET"
        }
        Pop-Location
    } catch {}
}

# Line 1: フォルダ名 | モデル | プラン | コンテキストバー | Git
$folderName = if ($currentDir) { Split-Path $currentDir -Leaf } else { "" }
$folderDisplay = if ($folderName) { "${folderName}${Sep}" } else { "" }
$line1 = "${folderDisplay}${ColModel}${modelName}${RESET}${planDisplay}${Sep}${contextBar} ${GRAY}${percentage}% (${usedK}k)${RESET}${gitInfo}${lowTokenWarning}"

Write-Host $line1
if ($fiveLine) { Write-Host $fiveLine }
if ($sevenDayLine) { Write-Host $sevenDayLine }