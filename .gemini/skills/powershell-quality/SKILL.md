---
name: powershell-quality
description: Comprehensive guide for generating high-quality PowerShell scripts with Japanese language support. Covers encoding (Shift_JIS for .ps1 files, UTF-8 for outputs), error handling, logging, SQL Server integration for GRANDIT ERP, and production-ready patterns.
---

# PowerShell Script Quality Skill

## スキルの目的
高品質で実用的なPowerShellスクリプトを生成するための包括的なガイドライン。特に日本語環境での使用を想定し、エンコーディング問題、エラーハンドリング、保守性を重視する。

## 必須要件

### 1. スクリプトヘッダー
すべてのスクリプトは以下の構造で開始する:

```powershell
<#
.SYNOPSIS
    スクリプトの簡潔な説明

.DESCRIPTION
    詳細な説明
    
.PARAMETER ParameterName
    パラメータの説明

.EXAMPLE
    .\Script.ps1 -ParameterName "value"
    使用例の説明

.NOTES
    FileName:  Script.ps1
    Author:    作成者名
    Created:   YYYY-MM-DD
    Version:   1.0
    
.LINK
    関連ドキュメントのURL（あれば）
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RequiredParam,
    
    [Parameter(Mandatory=$false)]
    [string]$OptionalParam = "デフォルト値"
)
```

### 2. エンコーディング対策（最重要）

**重要: .ps1ファイル自体のエンコーディング**

PowerShellスクリプトファイル（.ps1）に日本語が含まれる場合、ファイル自体は **Shift_JIS (SJIS)** で保存する必要があります。

```
✅ 正しい保存方法:
.ps1ファイル → Shift_JIS (SJIS) で保存
出力ファイル（ログ、CSV等） → UTF-8 で出力

❌ 誤った保存方法:
.ps1ファイル → UTF-8で保存（PowerShell 5.1で文字化けの原因）
```

理由:
- PowerShell 5.1（Windows標準）はスクリプトファイルをShift_JISとして読み込む
- UTF-8で保存すると、日本語コメントや文字列リテラルが文字化けする
- PowerShell 7+ではUTF-8対応だが、5.1との互換性のためSJIS推奨

**スクリプト冒頭で必ず設定:**

```powershell
# 日本語エンコーディング設定
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# PowerShell 5.1互換性も考慮する場合
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
}
```

**ファイル出力時の明示的なエンコーディング指定:**

```powershell
# ✅ 推奨パターン
$content | Out-File -FilePath $path -Encoding utf8
Add-Content -Path $path -Value $line -Encoding utf8
[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)

# ❌ 避けるべきパターン
$content > $path
$content | Out-File $path  # エンコーディング指定なし
```

**CSV出力の場合:**

```powershell
$data | Export-Csv -Path $path -Encoding utf8 -NoTypeInformation
```

### 3. エラーハンドリング

**基本パターン:**

```powershell
# スクリプト全体でエラー時停止
$ErrorActionPreference = 'Stop'

try {
    # 処理本体
    $result = Get-SomeData -Path $path
    
    if ($null -eq $result) {
        throw "データが取得できませんでした: $path"
    }
    
    # 処理続行
}
catch {
    Write-Error "エラーが発生しました: $($_.Exception.Message)"
    Write-Error "エラー箇所: Line $($_.InvocationInfo.ScriptLineNumber)"
    
    # ログ出力
    $errorLog = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
    $errorLog | ConvertTo-Json | Out-File -FilePath "error.log" -Encoding utf8 -Append
    
    exit 1
}
finally {
    # クリーンアップ処理
    if ($connection) {
        $connection.Close()
    }
}
```

**コマンドレット個別のエラー制御:**

```powershell
# 特定のコマンドだけエラーを無視
$item = Get-Item -Path $path -ErrorAction SilentlyContinue

# 警告として扱う
Invoke-Command -ScriptBlock $script -ErrorAction Continue
```

### 4. ロギング

**構造化ログ関数:**

```powershell
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory=$false)]
        [string]$LogFile = ".\script.log"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # コンソール出力（レベルに応じて色分け）
    switch ($Level) {
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'WARN'  { Write-Host $logEntry -ForegroundColor Yellow }
        'DEBUG' { Write-Host $logEntry -ForegroundColor Gray }
        default { Write-Host $logEntry }
    }
    
    # ファイル出力
    $logEntry | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

# 使用例
Write-Log "処理を開始します" -Level INFO
Write-Log "警告: 一部のファイルが見つかりません" -Level WARN
Write-Log "エラー: データベース接続失敗" -Level ERROR
```

### 5. パラメータ設計

**バリデーション属性の活用:**

```powershell
param(
    # ファイルパス検証
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$InputFile,
    
    # 値の範囲指定
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,100)]
    [int]$RetryCount = 3,
    
    # 選択肢の限定
    [Parameter(Mandatory=$false)]
    [ValidateSet('Development','Staging','Production')]
    [string]$Environment = 'Development',
    
    # パターンマッチング
    [Parameter(Mandatory=$false)]
    [ValidatePattern('^[A-Z]{3}-\d{4}$')]
    [string]$ProjectCode,
    
    # 空文字チェック
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName
)
```

### 6. パフォーマンスとベストプラクティス

**配列の扱い:**

```powershell
# ❌ 避けるべき（遅い）
$results = @()
foreach ($item in $items) {
    $results += Process-Item $item
}

# ✅ 推奨（高速）
$results = foreach ($item in $items) {
    Process-Item $item
}

# または
$results = $items | ForEach-Object { Process-Item $_ }
```

**パイプライン vs foreach:**

```powershell
# 大量データ処理: foreach推奨（メモリ効率）
foreach ($file in Get-ChildItem -Path $path) {
    Process-File $file
}

# 少量データでシンプル: パイプライン可
Get-ChildItem -Path $path | Where-Object {$_.Length -gt 1MB} | Process-File
```

**進捗表示:**

```powershell
$items = Get-ChildItem -Path $path
$total = $items.Count
$current = 0

foreach ($item in $items) {
    $current++
    Write-Progress -Activity "処理中" -Status "$current / $total" -PercentComplete (($current / $total) * 100)
    Process-Item $item
}
Write-Progress -Activity "処理中" -Completed
```

### 7. バージョン互換性

**PowerShell 5.1 と 7+ の両対応:**

```powershell
# バージョン判定
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # PowerShell 7以降の機能使用可
    $data | ConvertTo-Json -Depth 10 -AsArray
} else {
    # PowerShell 5.1互換コード
    $data | ConvertTo-Json -Depth 10
}

# クロスプラットフォーム対応
if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    # Windows固有処理
    $path = "C:\Temp\file.txt"
} else {
    # Linux/macOS処理
    $path = "/tmp/file.txt"
}
```

### 8. SQL Server連携（GRANDIT案件向け）

**接続とクエリ実行:**

```powershell
# SqlServer モジュールのインポート
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Log "SqlServerモジュールをインストールします" -Level WARN
    Install-Module -Name SqlServer -Scope CurrentUser -Force
}
Import-Module SqlServer

# 接続情報
$serverInstance = "localhost\SQLEXPRESS"
$database = "GRANDIT"

# クエリ実行（エラーハンドリング付き）
try {
    $query = @"
SELECT 
    得意先コード,
    得意先名
FROM 
    M_得意先
WHERE
    削除フラグ = 0
"@

    $results = Invoke-Sqlcmd -ServerInstance $serverInstance `
                             -Database $database `
                             -Query $query `
                             -ErrorAction Stop
    
    # 結果をCSV出力
    $results | Export-Csv -Path "得意先一覧.csv" -Encoding utf8 -NoTypeInformation
    Write-Log "得意先データを出力しました: $($results.Count)件" -Level INFO
}
catch {
    Write-Log "SQLクエリ実行エラー: $($_.Exception.Message)" -Level ERROR
    throw
}
```

**接続文字列を使った接続:**

```powershell
$connectionString = "Server=$serverInstance;Database=$database;Integrated Security=True;TrustServerCertificate=True"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

try {
    $connection.Open()
    Write-Log "データベース接続成功" -Level INFO
    
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | Out-Null
    
    $results = $dataset.Tables[0]
}
finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}
```

### 9. ファイル操作

**安全なファイル操作:**

```powershell
# ディレクトリ存在確認と作成
$outputDir = ".\output"
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Log "出力ディレクトリを作成しました: $outputDir" -Level INFO
}

# ファイル存在確認
if (Test-Path -Path $inputFile) {
    Write-Log "入力ファイルを検出: $inputFile" -Level INFO
} else {
    Write-Log "入力ファイルが見つかりません: $inputFile" -Level ERROR
    exit 1
}

# バックアップ作成
$backupFile = "$inputFile.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
Copy-Item -Path $inputFile -Destination $backupFile
Write-Log "バックアップを作成しました: $backupFile" -Level INFO
```

### 10. 設定ファイル活用

**JSON設定ファイル読み込み:**

```powershell
# config.json
<#
{
    "ServerInstance": "localhost\\SQLEXPRESS",
    "Database": "GRANDIT",
    "OutputPath": "./output",
    "RetryCount": 3,
    "LogLevel": "INFO"
}
#>

$configPath = Join-Path $PSScriptRoot "config.json"

if (Test-Path -Path $configPath) {
    $config = Get-Content -Path $configPath -Encoding utf8 | ConvertFrom-Json
    Write-Log "設定ファイルを読み込みました" -Level INFO
} else {
    Write-Log "設定ファイルが見つかりません: $configPath" -Level ERROR
    exit 1
}

# 設定値の使用
$serverInstance = $config.ServerInstance
$database = $config.Database
```

### 11. テスト可能な設計

**関数分割:**

```powershell
# 処理を関数に分割
function Get-CustomerData {
    [CmdletBinding()]
    param(
        [string]$ServerInstance,
        [string]$Database
    )
    
    $query = "SELECT * FROM M_得意先 WHERE 削除フラグ = 0"
    $results = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query
    return $results
}

function Export-CustomerData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Data,
        [string]$OutputPath
    )
    
    $Data | Export-Csv -Path $OutputPath -Encoding utf8 -NoTypeInformation
}

# メイン処理
try {
    $customers = Get-CustomerData -ServerInstance $serverInstance -Database $database
    Export-CustomerData -Data $customers -OutputPath "得意先.csv"
}
catch {
    Write-Log "処理失敗: $($_.Exception.Message)" -Level ERROR
    exit 1
}
```

## チェックリスト

スクリプト作成時に以下を確認:

- [ ] **スクリプトファイル（.ps1）をShift_JIS (SJIS) で保存**（日本語が含まれる場合）
- [ ] スクリプトヘッダー（.SYNOPSIS, .DESCRIPTION等）を記述
- [ ] エンコーディング設定を明示（UTF-8）
- [ ] すべてのファイル出力に `-Encoding utf8` を指定
- [ ] `$ErrorActionPreference = 'Stop'` を設定
- [ ] try-catch-finally でエラーハンドリング
- [ ] ログ出力機能を実装
- [ ] パラメータにバリデーション属性を設定
- [ ] 進捗表示を実装（長時間処理の場合）
- [ ] PowerShell 5.1 との互換性確認
- [ ] 一時ファイル/接続のクリーンアップを finally で実行
- [ ] 日本語コメントとメッセージが正しく表示されるか確認

## 出力形式

生成するスクリプトは以下の構造に従う:

1. スクリプトヘッダー(コメントブロック)
2. パラメータ定義
3. エンコーディング設定
4. グローバル変数・設定
5. 関数定義（あれば）
6. メイン処理（try-catch-finally）
7. 終了処理

**重要: ファイル作成時のエンコーディング指定**

AIツール（create_file等）でPowerShellスクリプトを作成する際は、ファイルエンコーディングをShift_JIS (SJIS) に指定すること:

```bash
# Linuxコンテナ環境での変換例
iconv -f UTF-8 -t SHIFT_JIS input.ps1 > output.ps1

# PowerShell環境での保存例
$content = Get-Content -Path "script.ps1" -Encoding utf8
$content | Out-File -FilePath "script_sjis.ps1" -Encoding default
```

## 使用例

このスキルを参照する際は以下のように指示:

「PowerShellスクリプトを作成してください。GRANDIT案件用のSQL Server連携スクリプトで、得意先マスタから削除されていないレコードを抽出しCSV出力します。PowerShell Script Quality Skillに従って実装してください。」

**重要な注意事項:**
- 生成された**日本語が含まれた**.ps1ファイルは **Shift_JIS (SJIS)** で保存すること
- スクリプト内の出力ファイル（ログ、CSV等）は **UTF-8** で出力される
- この2つのエンコーディングは異なる目的で使い分ける
