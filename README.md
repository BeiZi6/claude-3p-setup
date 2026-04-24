# claude-3p-setup

[中文文档](README_CN.md)

One-click setup script for configuring third-party API gateways in **Claude Desktop** (with Developer Mode & third-party inference enabled).

> **Sponsor**: [tt.xyucode.top](https://tt.xyucode.top/) — ¥0.5 per credit, official relay, MAX rate starting from 1x.

## Features

- Interactive gateway selection with built-in presets
- Auto-discovers available models via `/v1/models` endpoint
- Multi-profile support — create, switch, and manage named configurations
- Automatic backup before every write
- API key secured with silent input & `chmod 600`
- URL normalization (strips trailing `/v1`, enforces trailing `/`)
- Restart Claude Desktop after configuration

## Supported Platforms

| Platform | Script | Config Path |
|----------|--------|-------------|
| macOS    | `claude-3p-setup.sh` | `~/Library/Application Support/Claude-3p/configLibrary/` |
| Windows  | `claude-3p-setup.ps1` | `%APPDATA%\Claude-3p\configLibrary\` |

## Quick Start

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/BeiZi6/claude-3p-setup/main/claude-3p-setup.sh -o claude-3p-setup.sh
chmod +x claude-3p-setup.sh
bash claude-3p-setup.sh
```

**Requirements**: `jq`, `curl`, `uuidgen` (all pre-installed on macOS).

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/BeiZi6/claude-3p-setup/main/claude-3p-setup.ps1 -OutFile claude-3p-setup.ps1
.\claude-3p-setup.ps1
```

If you encounter an execution policy error:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**Requirements**: PowerShell 5.1+ (built into Windows 10/11).

## Usage

```bash
# Interactive setup
bash claude-3p-setup.sh

# List existing profiles
bash claude-3p-setup.sh --list

# Show help
bash claude-3p-setup.sh --help
```

```powershell
# Interactive setup
.\claude-3p-setup.ps1

# List existing profiles
.\claude-3p-setup.ps1 -List
```

## How It Works

Claude Desktop (with third-party inference enabled) reads its gateway configuration from:

```
configLibrary/
  _meta.json              # Profile index + active profile ID
  <uuid>.json             # Each profile: provider, baseUrl, apiKey, models
```

This script creates/updates these JSON files with proper structure and activates the selected profile.

## Built-in Gateway Presets

| Preset | URL | Note |
|--------|-----|------|
| xyucode (Recommended) | `https://tt.xyucode.top/` | ¥0.5/credit, official relay, MAX 1x |
| Custom | — | Enter your own URL |
| AnyRouter | `https://anyrouter.top/` | Anthropic-compatible relay |

## License

MIT
