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

# グラデーションカラー (Pythonのgradient()に合わせたRGB)
function Get-Gradient {
    param([double]$Pct)
    if ($Pct -lt 50) {
        $r = [int]($Pct * 5.1)
        return "$e[38;2;${r};200;80m"
    } else {
        $g = [math]::Max([int](200 - ($Pct - 50) * 4), 0)
        return "$e[38;2;255;${g};60m"
    }
}

# 点字ドットバー生成関数 (Pattern 5: Braille Dots)
# 8セル × 7段階、8セルごとにスペース1個
function New-BrailleBar {
    param(
        [double]$Percentage,
        [int]$Cells = 8,
        [int]$GroupSize = 8
    )
    # 参考実装に合わせたセット: 下から対称充填
    $brailleSteps = @(
        ' ',           # ' ' 0/7 (半角スペース)
        [char]0x28C0,  # ⣀ 1/7
        [char]0x28C4,  # ⣄ 2/7
        [char]0x28E4,  # ⣤ 3/7
        [char]0x28E6,  # ⣦ 4/7
        [char]0x28F6,  # ⣶ 5/7
        [char]0x28F7,  # ⣷ 6/7
        [char]0x28FF   # ⣿ 7/7
    )

    $level = [math]::Max(0.0, [math]::Min($Percentage / 100.0, 1.0))
    $bar = ""
    for ($i = 0; $i -lt $Cells; $i++) {
        # グループ間にスペース
        if ($i -gt 0 -and $i % $GroupSize -eq 0) { $bar += " " }

        $segStart = $i / $Cells
        $segEnd   = ($i + 1) / $Cells
        if ($level -ge $segEnd) {
            $bar += $brailleSteps[7]
        } elseif ($level -le $segStart) {
            $bar += $brailleSteps[0]
        } else {
            $frac = ($level - $segStart) / ($segEnd - $segStart)
            $bar += $brailleSteps[[math]::Min([int]($frac * 7), 7)]
        }
    }
    return $bar
}

# コンテキストバー
$ctxColor = Get-Gradient -Pct $percentage
$ctxBar = New-BrailleBar -Percentage $percentage -Cells 8
$contextBar = "$ctxColor$ctxBar$RESET"

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
# 4.5. レート制限 (stdinのrate_limitsから取得)
# ==========================================
$rlData = $null
if ($stdData.rate_limits) {
    $fh = $stdData.rate_limits.five_hour
    $sd = $stdData.rate_limits.seven_day
    $rlData = @{
        five_hour_util  = if ($fh -and $fh.used_percentage -ne $null) { [double]$fh.used_percentage / 100.0 } else { $null }
        five_hour_reset = if ($fh) { $fh.resets_at } else { $null }
        seven_day_util  = if ($sd -and $sd.used_percentage -ne $null) { [double]$sd.used_percentage / 100.0 } else { $null }
        seven_day_reset = if ($sd) { $sd.resets_at } else { $null }
    }
}

$fiveHourInline = ""
if ($rlData -and $rlData.five_hour_util -ne $null) {
    try {
        $f5Pct   = [int]([double]$rlData.five_hour_util * 100)
        $f5Color = Get-Gradient -Pct $f5Pct

        $f5Bar = New-BrailleBar -Percentage $f5Pct -Cells 8

        $f5Reset = ""
        if ($rlData.five_hour_reset) {
            $epoch   = [long]$rlData.five_hour_reset
            $resetDt = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
            $f5Reset = " ${GRAY}Resets $($resetDt.ToString('HH:mm'))$RESET"
        }

        $fiveLine = "${GRAY}[5h]${RESET} ${f5Color}${f5Bar}${RESET} ${f5Color}${f5Pct}%${RESET}${f5Reset}"
    } catch {}
}

$sevenDayLine = ""
if ($rlData -and $rlData.seven_day_util -ne $null) {
    try {
        $f7Pct   = [int]([double]$rlData.seven_day_util * 100)
        $f7Color = Get-Gradient -Pct $f7Pct

        $f7Bar = New-BrailleBar -Percentage $f7Pct -Cells 8

        $f7Reset = ""
        if ($rlData.seven_day_reset) {
            $epoch   = [long]$rlData.seven_day_reset
            $resetDt = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
            $f7Reset = " ${GRAY}Resets $($resetDt.ToString('M/d HH:mm'))$RESET"
        }

        $sevenDayLine = "${GRAY}[7d]${RESET} ${f7Color}${f7Bar}${RESET} ${f7Color}${f7Pct}%${RESET}${f7Reset}"
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