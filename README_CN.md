# claude-3p-setup

[English](README.md)

一键为 **Claude Code Desktop** 配置第三方 API 网关的交互式脚本（需开启开发者模式及第三方推理）。

本工具帮助小白快速在 Claude Code Desktop 中配置第三方 API 中转服务。使用官转可以享受 **1 小时 Prompt Cache** — 大幅降低延迟和成本。

![1h 缓存演示](images/1h-cache-demo.jpg)

> **推荐中转**: [tt.xyucode.top](https://tt.xyucode.top/) — 0.5 元一刀额度，官转 MAX 倍率 1 开头。

## 功能特点

- 交互式选择网关，内置常用预设
- 自动通过 `/v1/models` 拉取可用模型列表
- 多档案管理 — 创建、切换、复用已命名的配置
- 每次写入前自动备份
- API Key 静默输入，配置文件 `chmod 600` 保护
- URL 自动规范化（去除多余 `/v1`，强制补齐结尾 `/`）
- 配置完成后一键重启 Claude Desktop

## 支持平台

| 平台 | 脚本 | 配置路径 |
|------|------|---------|
| macOS | `claude-3p-setup.sh` | `~/Library/Application Support/Claude-3p/configLibrary/` |
| Windows | `claude-3p-setup.ps1` | `%APPDATA%\Claude-3p\configLibrary\` |

## 快速开始

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/BeiZi6/claude-3p-setup/main/claude-3p-setup.sh -o claude-3p-setup.sh
chmod +x claude-3p-setup.sh
bash claude-3p-setup.sh
```

**依赖**: `jq`、`curl`、`uuidgen`（macOS 自带）。

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/BeiZi6/claude-3p-setup/main/claude-3p-setup.ps1 -OutFile claude-3p-setup.ps1
.\claude-3p-setup.ps1
```

如遇执行策略限制：

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**依赖**: PowerShell 5.1+（Windows 10/11 自带）。

## 使用方法

```bash
# 交互式配置
bash claude-3p-setup.sh

# 列出现有配置档案
bash claude-3p-setup.sh --list

# 查看帮助
bash claude-3p-setup.sh --help
```

```powershell
# 交互式配置
.\claude-3p-setup.ps1

# 列出现有配置档案
.\claude-3p-setup.ps1 -List
```

## 工作原理

Claude Desktop（启用第三方推理后）从以下目录读取网关配置：

```
configLibrary/
  _meta.json              # 档案索引 + 当前激活的档案 ID
  <uuid>.json             # 每个档案: provider, baseUrl, apiKey, models
```

脚本会创建/更新这些 JSON 文件并激活所选档案。

## 内置网关预设

| 预设 | URL | 说明 |
|------|-----|------|
| xyucode（推荐） | `https://tt.xyucode.top/` | 0.5 元一刀额度，官转 MAX 倍率 1 开头 |
| 自定义 | — | 手动输入 URL |
| AnyRouter | `https://anyrouter.top/` | Anthropic 兼容中转 |
| DeepSeek | `https://api.deepseek.com/anthropic` | DeepSeek 官方 Anthropic 兼容端点 |

## 许可证

MIT
