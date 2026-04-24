#Requires -Version 5.1
<#
.SYNOPSIS
  一键为 Claude Desktop (Windows) 配置第三方 API Gateway
.DESCRIPTION
  适用：已开启 Developer Mode 并启用第三方推理的 Claude Desktop
.EXAMPLE
  .\claude-3p-setup.ps1            # 交互式配置
  .\claude-3p-setup.ps1 -List      # 列出现有配置档案
#>
[CmdletBinding(DefaultParameterSetName = 'Setup')]
param(
    [Parameter(ParameterSetName = 'List')]
    [switch]$List
)

$ErrorActionPreference = 'Stop'

# ---------- 常量 ----------
$ClaudeDir = Join-Path $env:APPDATA 'Claude-3p'
$LibDir    = Join-Path $ClaudeDir 'configLibrary'
$MetaFile  = Join-Path $LibDir '_meta.json'
$BackupDir = Join-Path $ClaudeDir 'configLibrary.bak'

# ---------- 颜色辅助 ----------
function Write-Info  { param($Msg) Write-Host "i  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param($Msg) Write-Host "✓  $Msg" -ForegroundColor Green }
function Write-Warn  { param($Msg) Write-Host "⚠  $Msg" -ForegroundColor Yellow }
function Write-Err   { param($Msg) Write-Host "✗  $Msg" -ForegroundColor Red }

# ---------- 预设网关 ----------
$Presets = @(
    @{ Name = 'xyucode 中转 ★推荐';               Url = 'https://tt.xyucode.top/';  Desc = '0.5 美元一刀, 官转 MAX 倍率 1 开头' }
    @{ Name = '自定义 (手动输入)';                   Url = '__custom__';               Desc = '手动输入 Base URL' }
    @{ Name = 'AnyRouter';                          Url = 'https://anyrouter.top/';   Desc = 'Anthropic 兼容中转' }
    @{ Name = 'DeepSeek (Anthropic 兼容)';   Url = 'https://api.deepseek.com/anthropic'; Desc = 'DeepSeek 官方 Anthropic 兼容端点' }
    @{ Name = 'Moonshot Kimi (OpenAI 兼容)';        Url = 'https://api.moonshot.cn/';  Desc = '需外层做协议转换' }
)

# ---------- 工具函数 ----------
function Ensure-Dir {
    if (-not (Test-Path $ClaudeDir)) {
        Write-Err "未找到 Claude Desktop 配置目录:"
        Write-Err "  $ClaudeDir"
        Write-Err "请先安装 Claude Desktop 并至少启动一次。"
        exit 1
    }
    if (-not (Test-Path $LibDir)) { New-Item -ItemType Directory -Path $LibDir -Force | Out-Null }
}

function Ensure-Meta {
    if (-not (Test-Path $MetaFile)) {
        '{"appliedId":null,"entries":[]}' | Set-Content -Path $MetaFile -Encoding UTF8
    }
}

function Get-Meta {
    Get-Content -Path $MetaFile -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-Meta {
    param($Meta)
    $Meta | ConvertTo-Json -Depth 10 | Set-Content -Path $MetaFile -Encoding UTF8
}

function Show-Profiles {
    Ensure-Meta
    $meta = Get-Meta
    Write-Host "`n现有配置档案:" -ForegroundColor White
    foreach ($e in $meta.entries) {
        $marker = if ($e.id -eq $meta.appliedId) { '●' } else { ' ' }
        Write-Host "  $marker $($e.name)  [$($e.id)]"
    }
    Write-Host ''
}

function Backup-Library {
    if (Test-Path $LibDir) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        $dest = "$BackupDir-$ts"
        Copy-Item -Path $LibDir -Destination $dest -Recurse -Force
        Write-Ok "已备份现有配置到: $dest"
    }
}

function Normalize-BaseUrl {
    param([string]$Url)
    $Url = $Url.TrimEnd('/')
    if ($Url.EndsWith('/v1')) { $Url = $Url.Substring(0, $Url.Length - 3) }
    return "$Url/"
}

function Fetch-Models {
    param([string]$BaseUrl, [string]$ApiKey)
    $endpoints = @("${BaseUrl}v1/models", "${BaseUrl}models")
    foreach ($ep in $endpoints) {
        try {
            $headers = @{
                'Authorization'     = "Bearer $ApiKey"
                'x-api-key'         = $ApiKey
                'anthropic-version' = '2023-06-01'
            }
            $resp = Invoke-RestMethod -Uri $ep -Headers $headers -TimeoutSec 15 -ErrorAction Stop
            if ($resp.data) {
                return ($resp.data | ForEach-Object { $_.id } | Sort-Object -Unique)
            }
        } catch {
            continue
        }
    }
    return $null
}

function Prompt-Input {
    param([string]$Message, [string]$Default = '')
    if ($Default) {
        $ans = Read-Host "$Message [$Default]"
        if ([string]::IsNullOrWhiteSpace($ans)) { return $Default }
        return $ans
    }
    return Read-Host $Message
}

function Prompt-Secret {
    param([string]$Message)
    $secure = Read-Host $Message -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}

# ---------- 主流程 ----------
Ensure-Dir

if ($List) {
    Show-Profiles
    exit 0
}

Write-Host ''
Write-Host '╔════════════════════════════════════════════════╗' -ForegroundColor White
Write-Host '║   Claude Desktop 第三方网关一键配置 (Windows)    ║' -ForegroundColor White
Write-Host '╚════════════════════════════════════════════════╝' -ForegroundColor White
Write-Host ''

Ensure-Meta
Show-Profiles

# ---- 1. 选网关 ----
Write-Host '请选择网关预设:' -ForegroundColor White
for ($i = 0; $i -lt $Presets.Count; $i++) {
    $p = $Presets[$i]
    Write-Host ("  {0}) {1,-40} {2}" -f ($i + 1), $p.Name, $p.Desc) -ForegroundColor Cyan
}
$sel = Prompt-Input '输入编号' '1'
$idx = [int]$sel - 1
if ($idx -lt 0 -or $idx -ge $Presets.Count) {
    Write-Err '无效选择'; exit 1
}
$chosen = $Presets[$idx]

if ($chosen.Url -eq '__custom__') {
    $BaseUrl = Prompt-Input '请输入网关 Base URL (必须以 / 结尾, 例: https://tt.xyucode.top/)'
} else {
    $BaseUrl = Prompt-Input 'Base URL' $chosen.Url
}
$BaseUrl = Normalize-BaseUrl $BaseUrl

# ---- 2. API Key ----
$ApiKey = Prompt-Secret '请输入 API Key (sk-...)'
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Err 'API Key 不能为空'; exit 1
}

# ---- 3. 拉模型 ----
Write-Info "尝试从 ${BaseUrl}v1/models 拉取模型列表..."
$models = Fetch-Models -BaseUrl $BaseUrl -ApiKey $ApiKey

if ($models) {
    $modelList = @($models)
    Write-Ok "成功拉取到 $($modelList.Count) 个模型"
    Write-Host ''
    Write-Host '可用模型:' -ForegroundColor White
    for ($i = 0; $i -lt $modelList.Count; $i++) {
        Write-Host ("  {0,2}) {1}" -f ($i + 1), $modelList[$i])
    }
    Write-Host ''
    $selModels = Prompt-Input '输入要启用的模型编号 (逗号分隔, 留空=全部)' ''
    if ([string]::IsNullOrWhiteSpace($selModels)) {
        $Selected = $modelList
    } else {
        $Selected = @()
        foreach ($n in ($selModels -split ',')) {
            $n = $n.Trim()
            $mi = [int]$n - 1
            if ($mi -ge 0 -and $mi -lt $modelList.Count) {
                $Selected += $modelList[$mi]
            }
        }
    }
} else {
    Write-Warn '无法自动拉取模型(接口未返回或鉴权失败),请手动输入'
    $manual = Prompt-Input '模型列表(逗号分隔,例: claude-opus-4-7,claude-sonnet-4-6)'
    $Selected = @($manual -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

if ($Selected.Count -eq 0) {
    Write-Err '未选择任何模型'; exit 1
}

# ---- 4. 档案名 ----
$ProfileName = Prompt-Input '为这个配置起个名字' 'Default'

# ---- 5. 写入 ----
Backup-Library

$meta = Get-Meta
$existing = $meta.entries | Where-Object { $_.name -eq $ProfileName } | Select-Object -First 1

if ($existing) {
    $ProfileId = $existing.id
    Write-Info "复用同名档案 $ProfileName ($ProfileId)"
} else {
    $ProfileId = [guid]::NewGuid().ToString()
    Write-Info "创建新档案 $ProfileName ($ProfileId)"
}

$ProfileFile = Join-Path $LibDir "$ProfileId.json"

$config = @{
    inferenceProvider       = 'gateway'
    inferenceGatewayBaseUrl = $BaseUrl
    inferenceGatewayApiKey  = $ApiKey
    inferenceModels         = @($Selected)
} | ConvertTo-Json -Depth 10

$config | Set-Content -Path $ProfileFile -Encoding UTF8

# 更新 _meta.json
$meta.appliedId = $ProfileId
$found = $false
$newEntries = @()
foreach ($e in $meta.entries) {
    if ($e.id -eq $ProfileId) {
        $e.name = $ProfileName
        $found = $true
    }
    $newEntries += $e
}
if (-not $found) {
    $newEntries += @{ id = $ProfileId; name = $ProfileName }
}
$meta.entries = $newEntries
Save-Meta $meta

Write-Ok "配置已写入: $ProfileFile"
Write-Ok "档案 '$ProfileName' 已设为激活"

# ---- 6. 重启 App ----
Write-Host ''
$restart = Prompt-Input '是否立即重启 Claude Desktop?' 'y'
if ($restart -match '^[Yy]') {
    $proc = Get-Process -Name 'Claude' -ErrorAction SilentlyContinue
    if ($proc) { $proc | Stop-Process -Force; Start-Sleep -Seconds 1 }
    $app = Get-ChildItem "$env:LOCALAPPDATA\Claude\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $app) { $app = Get-ChildItem "$env:PROGRAMFILES\Claude\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($app) {
        Start-Process $app.FullName
        Write-Ok '已重启 Claude Desktop'
    } else {
        Write-Warn '未找到 Claude.exe，请手动启动'
    }
}

Write-Host ''
Write-Ok '完成! 在 Claude Desktop 右上角模型下拉中应能看到:'
foreach ($m in $Selected) { Write-Host "    • $m" }
