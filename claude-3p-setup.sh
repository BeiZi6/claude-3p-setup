#!/usr/bin/env bash
# claude-3p-setup.sh
# 一键为 Claude Desktop (macOS) 配置第三方 API Gateway
# 适用：已开启 Developer Mode 并启用第三方推理的 Claude Desktop
#
# Usage:  bash claude-3p-setup.sh
#         bash claude-3p-setup.sh --preset        # 使用内置网关预设
#         bash claude-3p-setup.sh --list          # 列出现有配置档案
#
set -euo pipefail

# ---------- 常量 ----------
CLAUDE_DIR="$HOME/Library/Application Support/Claude-3p"
LIB_DIR="$CLAUDE_DIR/configLibrary"
META_FILE="$LIB_DIR/_meta.json"
BACKUP_DIR="$CLAUDE_DIR/configLibrary.bak"

# ---------- 颜色 ----------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_CYAN=$'\033[36m'
else
  C_RESET=; C_BOLD=; C_GREEN=; C_YELLOW=; C_RED=; C_CYAN=
fi

info()  { echo "${C_CYAN}ℹ${C_RESET}  $*"; }
ok()    { echo "${C_GREEN}✓${C_RESET}  $*"; }
warn()  { echo "${C_YELLOW}⚠${C_RESET}  $*"; }
err()   { echo "${C_RED}✗${C_RESET}  $*" >&2; }

# ---------- 依赖检查 ----------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "缺少依赖: $1"; exit 1; }
}
need_cmd jq
need_cmd curl
need_cmd uuidgen

# ---------- 环境检查 ----------
if [[ ! -d "$CLAUDE_DIR" ]]; then
  err "未找到 Claude Desktop 配置目录:"
  err "  $CLAUDE_DIR"
  err "请先安装 Claude Desktop 并至少启动一次。"
  exit 1
fi
mkdir -p "$LIB_DIR"

# ---------- 预设网关 ----------
# name|baseUrl|描述
PRESETS=(
  "xyucode 中转 ★推荐|https://tt.xyucode.top/|0.5 美元一刀, 官转 MAX 倍率 1 开头"
  "自定义 (手动输入)|__custom__|手动输入 Base URL"
  "AnyRouter|https://anyrouter.top|Anthropic 兼容中转"
  "DeepSeek (Anthropic 兼容)|https://api.deepseek.com/anthropic|DeepSeek 官方 Anthropic 兼容端点"
  "Moonshot Kimi (OpenAI 兼容)|https://api.moonshot.cn|需外层做协议转换"
)

# ---------- 工具函数 ----------
backup_library() {
  if [[ -d "$LIB_DIR" ]]; then
    local ts; ts=$(date +%Y%m%d-%H%M%S)
    cp -R "$LIB_DIR" "$BACKUP_DIR-$ts"
    ok "已备份现有配置到: $BACKUP_DIR-$ts"
  fi
}

ensure_meta() {
  if [[ ! -f "$META_FILE" ]]; then
    echo '{"appliedId":null,"entries":[]}' > "$META_FILE"
  fi
}

list_profiles() {
  ensure_meta
  echo "${C_BOLD}现有配置档案:${C_RESET}"
  jq -r '
    .appliedId as $a |
    .entries[] |
    "  \(if .id==$a then "●" else " " end) \(.name)  [\(.id)]"
  ' "$META_FILE"
}

prompt() {  # prompt "提示" "默认值"
  local msg="$1" def="${2:-}" ans
  if [[ -n "$def" ]]; then
    read -r -p "$msg [$def]: " ans
    echo "${ans:-$def}"
  else
    read -r -p "$msg: " ans
    echo "$ans"
  fi
}

prompt_secret() {
  local msg="$1" ans
  read -r -s -p "$msg: " ans; echo >&2
  echo "$ans"
}

# 规范化 baseUrl: 去掉多余 /v1, 强制以 / 结尾
normalize_base_url() {
  local url="$1"
  url="${url%/}"
  url="${url%/v1}"
  echo "$url/"
}

fetch_models() {
  local base_url="$1" api_key="$2"
  # base_url 保证以 / 结尾
  local endpoints=("${base_url}v1/models" "${base_url}models")
  for ep in "${endpoints[@]}"; do
    local resp
    resp=$(curl -sS --max-time 15 -H "Authorization: Bearer $api_key" \
      -H "x-api-key: $api_key" -H "anthropic-version: 2023-06-01" \
      "$ep" 2>/dev/null) || continue
    # 支持 OpenAI 格式 {data:[{id}]} 或 Anthropic 格式 {data:[{id}]}
    local ids
    ids=$(echo "$resp" | jq -r '.data[]?.id // empty' 2>/dev/null | sort -u)
    if [[ -n "$ids" ]]; then
      echo "$ids"
      return 0
    fi
  done
  return 1
}

choose_preset() {
  echo "${C_BOLD}请选择网关预设:${C_RESET}"
  local i=1
  for row in "${PRESETS[@]}"; do
    IFS='|' read -r name url desc <<< "$row"
    printf "  %d) %-40s %s\n" "$i" "$name" "${C_CYAN}$desc${C_RESET}"
    ((i++))
  done
  local sel; sel=$(prompt "输入编号" "1")
  local idx=$((sel-1))
  if (( idx < 0 || idx >= ${#PRESETS[@]} )); then
    err "无效选择"; exit 1
  fi
  IFS='|' read -r PRESET_NAME PRESET_URL PRESET_DESC <<< "${PRESETS[$idx]}"
}

# ---------- 主流程 ----------
cmd="${1:-setup}"

case "$cmd" in
  --list|list)
    list_profiles
    exit 0
    ;;
  --help|-h|help)
    sed -n '2,10p' "$0"
    exit 0
    ;;
esac

echo "${C_BOLD}╔════════════════════════════════════════════╗${C_RESET}"
echo "${C_BOLD}║   Claude Desktop 第三方网关一键配置 (macOS) ║${C_RESET}"
echo "${C_BOLD}╚════════════════════════════════════════════╝${C_RESET}"
echo

ensure_meta
list_profiles || true
echo

# ---- 1. 选网关 ----
choose_preset
if [[ "$PRESET_URL" == "__custom__" ]]; then
  BASE_URL=$(prompt "请输入网关 Base URL (必须以 / 结尾, 例: https://tt.xyucode.top/)")
else
  BASE_URL=$(prompt "Base URL" "$PRESET_URL")
fi
BASE_URL=$(normalize_base_url "$BASE_URL")

# ---- 2. API Key ----
API_KEY=$(prompt_secret "请输入 API Key (sk-...)")
if [[ -z "$API_KEY" ]]; then
  err "API Key 不能为空"; exit 1
fi

# ---- 3. 拉模型 ----
info "尝试从 ${BASE_URL}v1/models 拉取模型列表..."
MODELS=()
if mapfile -t MODELS < <(fetch_models "$BASE_URL" "$API_KEY"); then
  ok "成功拉取到 ${#MODELS[@]} 个模型"
  echo
  echo "${C_BOLD}可用模型:${C_RESET}"
  for i in "${!MODELS[@]}"; do
    printf "  %2d) %s\n" "$((i+1))" "${MODELS[$i]}"
  done
  echo
  sel=$(prompt "输入要启用的模型编号 (逗号分隔, 留空=全部)" "")
  if [[ -z "$sel" ]]; then
    SELECTED=("${MODELS[@]}")
  else
    SELECTED=()
    IFS=',' read -ra nums <<< "$sel"
    for n in "${nums[@]}"; do
      n="${n// /}"
      idx=$((n-1))
      if (( idx >= 0 && idx < ${#MODELS[@]} )); then
        SELECTED+=("${MODELS[$idx]}")
      fi
    done
  fi
else
  warn "无法自动拉取模型(接口未返回或鉴权失败),请手动输入"
  manual=$(prompt "模型列表(逗号分隔,例: claude-opus-4-7,claude-sonnet-4-6)")
  SELECTED=()
  IFS=',' read -ra arr <<< "$manual"
  for m in "${arr[@]}"; do
    m="${m// /}"; [[ -n "$m" ]] && SELECTED+=("$m")
  done
fi

if (( ${#SELECTED[@]} == 0 )); then
  err "未选择任何模型"; exit 1
fi

# ---- 4. 档案名 ----
PROFILE_NAME=$(prompt "为这个配置起个名字" "Default")

# ---- 5. 写入 ----
backup_library

# 查找同名 profile
EXISTING_ID=$(jq -r --arg n "$PROFILE_NAME" '.entries[] | select(.name==$n) | .id' "$META_FILE" | head -n1)
if [[ -n "$EXISTING_ID" && "$EXISTING_ID" != "null" ]]; then
  PROFILE_ID="$EXISTING_ID"
  info "复用同名档案 $PROFILE_NAME ($PROFILE_ID)"
else
  PROFILE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
  info "创建新档案 $PROFILE_NAME ($PROFILE_ID)"
fi

PROFILE_FILE="$LIB_DIR/$PROFILE_ID.json"

jq -n \
  --arg base "$BASE_URL" \
  --arg key "$API_KEY" \
  --argjson models "$(printf '%s\n' "${SELECTED[@]}" | jq -R . | jq -s .)" \
  '{
    inferenceProvider: "gateway",
    inferenceGatewayBaseUrl: $base,
    inferenceGatewayApiKey: $key,
    inferenceModels: $models
  }' > "$PROFILE_FILE"
chmod 600 "$PROFILE_FILE"

# 更新 _meta.json
tmp=$(mktemp)
jq --arg id "$PROFILE_ID" --arg n "$PROFILE_NAME" '
  .appliedId = $id
  | if (.entries | map(.id) | index($id)) == null
    then .entries += [{id:$id, name:$n}]
    else .entries = (.entries | map(if .id==$id then .name=$n else . end))
    end
' "$META_FILE" > "$tmp" && mv "$tmp" "$META_FILE"

ok "配置已写入: $PROFILE_FILE"
ok "档案 '$PROFILE_NAME' 已设为激活"

# ---- 6. 重启 App ----
echo
if [[ "$(prompt "是否立即重启 Claude Desktop?" "y")" =~ ^[Yy] ]]; then
  osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
  sleep 1
  open -a "Claude" 2>/dev/null || warn "未找到 Claude.app,请手动启动"
  ok "已请求重启 Claude"
fi

echo
ok "完成!在 Claude Desktop 右上角模型下拉中应能看到:"
for m in "${SELECTED[@]}"; do echo "    • $m"; done
