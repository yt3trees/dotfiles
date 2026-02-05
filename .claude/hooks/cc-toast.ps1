<#
================================================================================
Claude Code 通知スクリプト (cc-toast.ps1)
================================================================================

【概要】
Claude CodeのNotification/StopイベントをWindows Toast通知で表示するhookスクリプト。
Claudeがアクティブウィンドウの場合は通知を抑制し、承認待ちやタスク完了などの
イベント種別に応じて異なるメッセージと通知音を表示します。

【重要：エンコーディング】
このファイルは必ず「BOM付きUTF-8」で保存してください！
- UTF-8（BOMなし）で保存すると、日本語が文字化けして構文エラーになります
- 変換方法: convert-encoding.ps1を実行するか、以下のコマンドを実行：
  $content = [System.IO.File]::ReadAllText('cc-toast.ps1', [System.Text.Encoding]::UTF8)
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  [System.IO.File]::WriteAllText('cc-toast.ps1', $content, $utf8Bom)

【settings.jsonでの設定例】
絶対パスを使用してください（相対パスだと動作しません）：

  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\hooks\\cc-toast.ps1\" -Event Notification -SilentWhenFocused"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\hooks\\cc-toast.ps1\" -Event Stop -SilentWhenFocused"
          }
        ]
      }
    ]
  }

【Claude Codeから受け取るpayloadの構造】
stdinからJSON形式で以下のような情報が渡されます：
{
  "session_id": "...",
  "hook_event_name": "Notification" or "Stop",
  "notification_type": "permission_prompt" or "user_input_required" など,
  "message": "Claude needs your permission to use Write",
  "title": "...",
  "project_name": "..."
}

【対応しているnotification_type】
- permission_prompt     → ✋ 承認待ち（Reminder音）
- user_input_required   → ⏸️ 入力待ち（IM音）
- task_completed        → ✅ 完了（Default音）
- task_failed           → ❌ エラー（Alarm音）
- background_task_done  → 🔔 バックグラウンド完了（SMS音）

【アクティブウィンドウ判定】
以下の場合は通知を抑制します（SilentWhenFocused=trueの場合）：
1. プロセス名/タイトルに"claude"が含まれる
2. Windows Terminal/PowerShellで、タイトルに"claude"が含まれる
3. Windows Terminal/PowerShellで、コマンドラインに"claude"が含まれる

【デバッグ】
デバッグログ: %USERPROFILE%\AppData\Local\Temp\cc-toast-debug.log
通知が表示されない場合は、このログを確認してください。

【パラメータ】
-Event              : Notification/Stop/Auto（Autoの場合はpayloadから自動判定）
-SilentWhenFocused  : Claudeがアクティブな場合に通知を抑制するか（デフォルト:true）

================================================================================
#>

param(
  [ValidateSet('Auto','Notification','Stop')] [string]$Event = 'Auto',
  [switch]$SilentWhenFocused
)

# switchパラメータが指定されていない場合、デフォルトでtrueとして扱う
if (-not $PSBoundParameters.ContainsKey('SilentWhenFocused')) {
  $SilentWhenFocused = $true
}

# 標準出力をUTF-8に固定（WSL経由のパイプ入力対策）
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# デバッグログ（問題解決後は削除可）
$logFile = "$env:TEMP\cc-toast-debug.log"
function Write-DebugLog {
  param([string]$msg)
  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-DebugLog "=== Script started, Event=$Event, SilentWhenFocused=$SilentWhenFocused ==="

# 1) HookからのJSON入力を読む（stdin）
$stdinText = $null
try { $stdinText = [Console]::In.ReadToEnd() } catch { Write-DebugLog "stdin read error: $_" }
$payload = $null
if ($stdinText) {
  Write-DebugLog "stdin received: $stdinText"
  try { $payload = $stdinText | ConvertFrom-Json } catch { Write-DebugLog "JSON parse error: $_" }
}
if ($Event -eq 'Auto' -and $payload -and $payload.hook_event_name) {
  $Event = $payload.hook_event_name
  Write-DebugLog "Event auto-detected: $Event"
}

# 2) 前面がClaudeなら通知中止
function Is-ClaudeForeground {
  # 型が既に定義されているかチェック（重複Add-Typeを防ぐ）
  $typeExists = 'User32' -as [Type]
  if (-not $typeExists) {
    Write-DebugLog "Adding User32 type"
    try {
      Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class User32 {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
}
"@
    } catch {
      Write-DebugLog "Add-Type error: $_"
    }
  } else {
    Write-DebugLog "User32 type already exists"
  }

  try {
    $h = [User32]::GetForegroundWindow()
    if ($h -eq [IntPtr]::Zero) {
      Write-DebugLog "No foreground window"
      return $false
    }

    $procId = 0
    [void][User32]::GetWindowThreadProcessId($h, [ref]$procId)

    $p = Get-Process -Id $procId -ErrorAction Stop
    $title = $p.MainWindowTitle
    $name  = $p.ProcessName
    Write-DebugLog "Foreground: name=$name, title=$title"

    # Claude Desktop / Claude Code のタイトル名やプロセス名で判定
    if ($title -match '(?i)claude( code)?' -or $name -match '(?i)claude') {
      Write-DebugLog "Claude is foreground -> suppressing notification"
      return $true
    }

    # ターミナル経由でCLI利用時の判定
    if ($name -match '(?i)windowsterminal|wt|powershell|pwsh|cmd') {
      Write-DebugLog "Terminal detected, checking title and command line..."

      # タイトルチェック
      if ($title -match '(?i)claude') {
        Write-DebugLog "Terminal with Claude in title -> suppressing notification"
        return $true
      }

      # コマンドラインチェック
      try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $procId" -ErrorAction Stop).CommandLine
        Write-DebugLog "CommandLine: $cmdLine"
        if ($cmdLine -match '(?i)claude') {
          Write-DebugLog "Terminal running Claude command -> suppressing notification"
          return $true
        }
      } catch {
        Write-DebugLog "Could not get command line: $_"
      }

      # ターミナルがアクティブな場合、claudeプロセスが実行中かチェック
      try {
        $claudeProcess = Get-Process -Name 'claude','claude-code' -ErrorAction SilentlyContinue
        if ($claudeProcess) {
          Write-DebugLog "Terminal is active and claude process is running -> suppressing notification"
          return $true
        }
      } catch {
        Write-DebugLog "Could not check for claude process: $_"
      }
    }
  } catch {
    Write-DebugLog "Is-ClaudeForeground error: $_"
    return $false
  }

  Write-DebugLog "Claude is NOT foreground"
  return $false
}

if ($SilentWhenFocused -and (Is-ClaudeForeground)) {
  Write-DebugLog "Exiting: Claude is foreground and SilentWhenFocused=true"
  exit 0
}

# 3) Windows Runtime でToast表示
function Show-Toast {
  param([string]$Title='Claude Code', [string]$Message='通知', [string]$AppId='Claude Code', [switch]$Silent, [string]$Sound='')
  Write-DebugLog "Show-Toast: Title=$Title, Message=$Message, Silent=$Silent, Sound=$Sound"
  try {
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $soundXml = if ($Silent) { '<audio silent="true"/>' } elseif ($Sound) { "<audio src='ms-winsoundevent:$Sound'/>" } else { '' }
    $template = @"
<toast>
  <visual>
    <binding template="ToastText02">
      <text id="1">$Title</text>
      <text id="2">$Message</text>
    </binding>
  </visual>
  $soundXml
</toast>
"@
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
    Write-DebugLog "Toast shown successfully"
  } catch {
    Write-DebugLog "Show-Toast error: $_"
  }
}

# 4) 表示内容の決定（Hookのpayload優先）
$title   = 'Claude Code'
$message = if ($Event -eq 'Notification') { '入力待ちです' } else { 'タスクが完了しました' }
$sound   = 'Notification.Default'
$silent  = $false

# payloadから詳細情報を抽出
if ($payload) {
  Write-DebugLog "Processing payload"

  # idle_prompt（入力待ち）は通知をスキップ
  if ($payload.notification_type -eq 'idle_prompt') {
    Write-DebugLog "idle_prompt detected -> skipping notification"
    exit 0
  }

  # タイトル設定
  if ($payload.title)        { $title = $payload.title }
  if ($payload.project_name) { $title = "📋 $($payload.project_name)" }

  # メッセージ設定
  if ($payload.message) { $message = $payload.message }

  # イベントタイプ別の処理（notification_typeを使用）
  if ($payload.notification_type) {
    Write-DebugLog "notification_type: $($payload.notification_type)"
    switch ($payload.notification_type) {
      'permission_prompt'     {
        $message = '✋ 承認待ち: ' + $message
        $sound = 'Notification.Reminder'
      }
      'user_input_required'   {
        $message = '⏸️ 入力待ち: ' + $message
        $sound = 'Notification.IM'
      }
      'task_completed'        {
        $message = '✅ 完了: ' + $message
        $sound = 'Notification.Default'
      }
      'task_failed'           {
        $message = '❌ エラー: ' + $message
        $sound = 'Notification.Looping.Alarm'
      }
      'background_task_done'  {
        $message = '🔔 バックグラウンド完了: ' + $message
        $sound = 'Notification.SMS'
      }
    }
  }
}

# イベント別のデフォルト処理
Write-DebugLog "Final: Event=$Event, title=$title, message=$message"
switch ($Event) {
  'Notification' {
    Show-Toast -Title $title -Message $message -AppId 'Claude Code' -Silent:$false -Sound $sound
  }
  'Stop' {
    if (-not $payload.notification_type) {
      $message = '✅ タスクが完了しました'
    }
    Show-Toast -Title $title -Message $message -AppId 'Claude Code' -Silent:$silent -Sound $sound
  }
  default {
    Show-Toast -Title $title -Message $message -AppId 'Claude Code' -Silent:$true
  }
}

Write-DebugLog "=== Script completed ==="
