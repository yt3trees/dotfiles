[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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
$ctxFilled = ([char]0x2588).ToString() * $ctxBarCount
$ctxEmpty = ([char]0x2591).ToString() * (10 - $ctxBarCount)

$contextBar = "$ctxColor$ctxFilled$GRAY$ctxEmpty$RESET"

# ==========================================
# 3. ccusage データ取得 (キャッシュ処理)
# ==========================================
$ccData = $null
$cacheFile = Join-Path $env:TEMP "claude_ccusage_cache.json"
$cacheDurationMinutes = 5

if (Test-Path $cacheFile) {
    try {
        $rawContent = Get-Content $cacheFile -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($rawContent)) { $ccData = $rawContent | ConvertFrom-Json }
    } catch {}
}

$shouldUpdate = $true
if ($ccData) {
    $lastWrite = (Get-Item $cacheFile).LastWriteTime
    if ((Get-Date) -lt $lastWrite.AddMinutes($cacheDurationMinutes)) { $shouldUpdate = $false }
}

if ($shouldUpdate) {
    if (Get-Command "npx" -ErrorAction SilentlyContinue) {
        $cmd = "npx --yes ccusage@latest blocks --active --json"
        try {
            $rawOutput = Invoke-Expression $cmd 2>$null
            if ($rawOutput -match "(\{.*`"blocks`".*\})") {
                $jsonPart = $matches[1]
                $newData = $jsonPart | ConvertFrom-Json
                if ($newData -and $newData.blocks) {
                    Set-Content -Path $cacheFile -Value $jsonPart -Encoding UTF8
                    $ccData = $newData
                }
            }
        } catch {}
    }
}

# ==========================================
# 4. 詳細情報の計算
# ==========================================
$resetInfo = ""
$costInfo = ""
$foundResetTime = $false

if ($ccData -and $ccData.blocks) {
    $block = $ccData.blocks | Where-Object { $_.isActive -eq $true } | Select-Object -First 1
    if (-not $block) { $block = $ccData.blocks | Select-Object -First 1 }

    if ($block -and $block.endTime) {
        try {
            # リセット時間
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

            # コストバー
            if ($block.costUSD) {
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
            }
            $foundResetTime = $true
        } catch {}
    }
}

# フォールバック
if (-not $foundResetTime) {
    if ($percentage -eq 0) {
        $resetInfo = "$Sep${GREEN}New Session$RESET"
    } elseif ($transcriptPath -and (Test-Path $transcriptPath)) {
        $fileCreated = (Get-Item $transcriptPath).CreationTime
        $resetTime = $fileCreated.AddHours(5)
        $remaining = $resetTime - (Get-Date)
        if ($remaining.TotalSeconds -gt 0) {
            $h = [math]::Floor($remaining.TotalHours)
            $m = $remaining.Minutes
            $resetInfo = "$Sep$nfClock ${ColPlan}${h}h${m}m$RESET (Est)"
        } else {
            $resetInfo = "$Sep$nfCheck ${GREEN}Available$RESET"
        }
    }
}

# ==========================================
# 5. 出力
# ==========================================
$lowTokenWarning = ""
if ($percentage -ge 80) { $lowTokenWarning = "$Sep$RED$nfWarn Low tokens$RESET" }

# Line 1: モデル | プラン | バー | % (k) | コスト | リセット
# ★修正: (${usedK}k) を追加
$line1 = "$ColModel$modelName$RESET$planDisplay$Sep$contextBar $GRAY${percentage}% (${usedK}k)$RESET$costInfo$resetInfo$lowTokenWarning"

# Line 2: パス Git
$pathParts = $currentDir
if ($currentDir) {
    $parts = $currentDir -split '[\\/]' | Where-Object { $_ -ne "" }
    if ($parts.Count -gt 3) { $pathParts = "...\" + ($parts[-3..-1] -join '\') }
}

$gitInfo = ""
if ($currentDir -and (Test-Path $currentDir)) {
    try {
        Push-Location $currentDir
        $isGitRepo = $false
        git rev-parse --git-dir 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $isGitRepo = $true }

        if ($isGitRepo) {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null

            # --- Git Status ---
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

$line2 = "$ColPathText$pathParts$RESET$gitInfo"

Write-Host $line1
Write-Host $line2