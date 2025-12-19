#!/usr/bin/env bash
# ==============================================
# AI CLI 管理器 v1.0.1
# - Qoder CLI 改为 qodercli --version
# - 逐项检测版本（cmd --version / -v）
# - Gemini: npm 管理
# - Kimi: uv 管理（--python 3.13）
# - Qwen: 官方命令 @qwen-code/qwen-code@latest
# - 升级 & 顽固卸载逻辑保持不变
# ==============================================

set -o pipefail

SCRIPT_VERSION="1.0.1"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
AUTO_MODE=0
CRON_MARKER="# AI CLI 管理器自动更新"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
AUTO_MODE=0

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage(){
  cat <<EOF
AI CLI 管理器 v${SCRIPT_VERSION}

用法:
  $(basename "$0")                        # 进入交互界面
  $(basename "$0") --version              # 显示版本号
  $(basename "$0") --help                 # 显示帮助
  $(basename "$0") --auto-upgrade         # 非交互：升级所有“可升级”的已安装 CLI，并显示当前版本
  $(basename "$0") --setup-daily [HH:MM]  # 写入 crontab：每日 HH:MM 自动升级（默认 03:00）
  $(basename "$0") --remove-daily         # 移除自动升级的 crontab 条目
EOF
}

divider(){ echo "--------------------------------------------------------------------------------"; }

# 计算终端“显示宽度”（解决中文/emoji 宽字符导致的列错位）
display_width(){
  local s="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$s" <<'PY'
import sys, re, unicodedata
s = sys.argv[1]
# Strip ANSI escape sequences to avoid miscounting
s = re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', s)
w = 0
for ch in s:
    if unicodedata.combining(ch):
        continue
    w += 2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1
print(w, end="")
PY
  else
    # Fallback: byte length (may misalign for wide chars)
    echo "${#s}"
  fi
}

pad_display(){
  local s="$1" target="$2"
  local w pad
  w="$(display_width "$s")"
  pad=$((target - w))
  (( pad < 0 )) && pad=0
  printf "%s%*s" "$s" "$pad" ""
}

pad_display_right(){
  local s="$1" target="$2"
  local w pad
  w="$(display_width "$s")"
  pad=$((target - w))
  (( pad < 0 )) && pad=0
  printf "%*s%s" "$pad" "" "$s"
}

COL_NO=4
COL_NAME=15
COL_VER=12
COL_STATUS=8

print_table_row(){
  local no="$1" name="$2" cur="$3" lat="$4" status="$5" note="$6" status_color="${7:-}"
  pad_display_right "$no" "$COL_NO"; printf "  "
  pad_display "$name" "$COL_NAME"; printf "  "
  pad_display "$cur" "$COL_VER"; printf "  "
  pad_display "$lat" "$COL_VER"; printf "  "
  [[ -n "$status_color" ]] && printf "%b" "$status_color"
  pad_display "$status" "$COL_STATUS"
  [[ -n "$status_color" ]] && printf "%b" "$NC"
  if [[ -n "$note" ]]; then
    printf "  %b\n" "$note"
  else
    printf "\n"
  fi
}

print_table_row_short(){
  local no="$1" name="$2" cur="$3"
  pad_display_right "$no" "$COL_NO"; printf "  "
  pad_display "$name" "$COL_NAME"; printf "  "
  pad_display "$cur" "$COL_VER"; printf "\n"
}

# 提取版本号（修复了换行符问题）
extract_ver(){
  local version_string="$1"
  local extracted
  extracted=$(
    echo "$version_string" \
      | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' \
      | head -n1 \
      | tr -d '\n\r'
  )
  if [[ -n "$extracted" ]]; then
    echo "$extracted"
  else
    echo "-"
  fi
}

# ---------- CLI 列表 ----------
# 显示名 | 命令 | 包名 | 管理器(npm/uv) | 版本子命令（可选）
CLI_LIST=(
  "Qoder|qodercli|@qoder-ai/qodercli|npm"
  "Codex|codex|@openai/codex|npm"
  "Gemini|gemini|@google/gemini-cli|npm"
  "Cline CLI|cline|cline|npm|version"
  "Claude Code|claude|@anthropic-ai/claude-code|npm"
  "Qwen Code|qwen|@qwen-code/qwen-code@latest|npm"
  "Grok|grok|@vibe-kit/grok-cli|npm"
  "IFlow CLI|iflow|@iflow-ai/iflow-cli|npm"
  "Kimi CLI|kimi|kimi-cli|uv"
)

# ---------- 本地版本 ----------
get_local_version(){
  local cmd="$1"
  local ver_cmd="${2:-}"
  if command -v "$cmd" >/dev/null 2>&1; then
    local raw
    if [[ -n "$ver_cmd" ]]; then
      raw=$("$cmd" "$ver_cmd" 2>/dev/null || echo "-")
    else
      raw=$("$cmd" --version 2>/dev/null || "$cmd" -v 2>/dev/null || "$cmd" version 2>/dev/null || echo "-")
    fi
    extract_ver "$raw"
  else
    echo "-"
  fi
}

# ---------- 远端最新 ----------
pypi_latest(){
  local p="$1"
  local version=""
  if command -v python3 >/dev/null 2>&1; then
    version=$(
      curl -sL -A "Mozilla/5.0" "https://pypi.org/pypi/${p}/json" \
        | python3 -c 'import sys, json; print(json.load(sys.stdin)["info"]["version"], end="")' 2>/dev/null \
        | tr -d '\n\r'
    )
  else
    version=$(curl -sL -A "Mozilla/5.0" "https://pypi.org/pypi/${p}/json" \
      | grep -Eo '"version":\s*"[^"]+"' | head -n1 \
      | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | tr -d '\n\r')
  fi
  if [[ -n "$version" ]]; then
    echo "$version"
  else
    echo "-"
  fi
}

get_latest_version(){
  local pkg="$1" mgr="$2"
  local raw_version=""
  case "$mgr" in
    npm)  raw_version=$(npm view "$pkg" version 2>/dev/null | tr -d '\n\r' || echo "-") ;; 
    uv)   raw_version=$(pypi_latest "$pkg") ;; 
    *)    raw_version="-" ;; 
  esac
  echo "$raw_version"
}

cmp_status(){
  local cur="$1" lat="$2"
  if [[ "$cur" == "-" ]]; then echo "未安装"
  elif [[ "$lat" == "-" ]]; then echo "未知"
  elif [[ "$cur" == "$lat" ]]; then echo "最新"
  else echo "可升级"; fi
}

# ---------- uv 依赖 ----------
ensure_uv(){
  if ! command -v uv >/dev/null 2>&1; then
    if [[ "$AUTO_MODE" == "1" ]]; then
      echo -e "${RED}⚠️  AUTO 模式下未找到 uv，跳过 uv 管理的 CLI。${NC}"
      return 1
    fi
    echo -e "${YELLOW}⚠️ 需要 uv，是否安装？(y/n) ${NC}"
    read -r c; [[ "$c" == "y" ]] || { echo -e "${BLUE}❌ 取消${NC}"; return 1; }
    curl -LsSf https://astral.sh/uv/install.sh | sh || return 1
    echo -e "${GREEN}✅ uv 已安装，请重新运行脚本以让 PATH 生效。${NC}"; exit 0
  fi
}

# ---------- npm 依赖 ----------
ensure_npm(){
  if ! command -v npm >/dev/null 2>&1; then
    if [[ "$AUTO_MODE" == "1" ]]; then
      echo -e "${RED}⚠️  AUTO 模式下未找到 npm，无法自动升级 npm 管理的 CLI。${NC}"
      return 1
    fi
    echo -e "${RED}⚠️ 检测到 npm 未安装。许多 CLI 需要 npm 进行管理。${NC}"
    echo "💡 建议通过 Node.js 官网安装 (https://nodejs.org/zh-cn/) 或使用 Homebrew (brew install node)。"
    echo -e "❓ 是否要继续运行脚本？(y/n) ${YELLOW}（如果继续，部分功能可能受限）${NC}"
    read -r c; [[ "$c" == "y" ]] || { echo -e "${BLUE}❌ 取消运行。${NC}"; exit 0; }
  fi
}

# ---------- 自动升级（非交互，可用于定时任务） ----------
auto_upgrade_installed(){
  AUTO_MODE=1
  local npm_available=1
  if ! command -v npm >/dev/null 2>&1; then
    npm_available=0
    echo -e "${RED}⚠️  AUTO 模式下未找到 npm，跳过 npm 管理的 CLI。${NC}"
  fi
  local upgraded=0
  for entry in "${CLI_LIST[@]}"; do
    IFS='|' read -r _name cmd pkg mgr ver_cmd <<< "$entry"
    if [[ "$mgr" == "npm" && "$npm_available" -eq 0 ]]; then
      continue
    fi
    cur="$(get_local_version "$cmd" "$ver_cmd")"
    [[ "$cur" == "-" ]] && continue
    lat="$(get_latest_version "$pkg" "$mgr")"
    if [[ "$lat" == "-" ]]; then
      echo "ℹ️ 跳过 ${_name}（最新版本未知）"
      continue
    fi
    if [[ "$cur" != "$lat" ]]; then
      upgrade_cli "$pkg" "$mgr"
      upgraded=1
    fi
  done
  if [[ "$upgraded" -eq 0 ]]; then
    echo "✅ 已安装的 CLI 均为最新，无需升级。"
  fi
  echo
  echo "📋 当前版本："
  show_current_versions
}

# ---------- crontab 管理 ----------
parse_time(){
  local input="$1"
  [[ "$input" =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]] || return 1
  local hour="${BASH_REMATCH[1]}" minute="${BASH_REMATCH[2]}"
  printf "%02d %02d" "$hour" "$minute"
}

install_cron_job(){
  if ! command -v crontab >/dev/null 2>&1; then
    echo -e "${RED}❌ 未找到 crontab，无法写入计划任务。${NC}"
    return 1
  fi

  local time_input="${1:-}"
  if [[ -z "$time_input" && -t 0 ]]; then
    read -rp "⏰ 输入每天自动升级时间 (HH:MM，默认 10:00): " time_input
  fi
  [[ -z "$time_input" ]] && time_input="10:00"

  if ! cron_time="$(parse_time "$time_input")"; then
    echo -e "${RED}❌ 时间格式错误，请使用 HH:MM（例如 03:00 或 18:30）。${NC}"
    return 1
  fi
  local hour minute
  hour="$(echo "$cron_time" | awk '{print $1}')"
  minute="$(echo "$cron_time" | awk '{print $2}')"

  local line="${minute} ${hour} * * * \"${SCRIPT_PATH}\" --auto-upgrade >/tmp/ai-manager-auto.log 2>&1"
  local tmp
  tmp="$(mktemp)"
  crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | grep -v "$SCRIPT_PATH --auto-upgrade" >"$tmp" || true
  echo "$CRON_MARKER" >>"$tmp"
  echo "$line" >>"$tmp"
  if crontab "$tmp"; then
    echo -e "${GREEN}✅ 已写入 crontab：每日 ${hour}:${minute} 自动升级已安装（可升级的）CLI${NC}"
    echo "日志: /tmp/ai-manager-auto.log"
  else
    echo -e "${RED}❌ 写入 crontab 失败${NC}"
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

remove_cron_job(){
  if ! command -v crontab >/dev/null 2>&1; then
    echo -e "${RED}❌ 未找到 crontab，无法移除计划任务。${NC}"
    return 1
  fi
  local tmp
  tmp="$(mktemp)"
  crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | grep -v "$SCRIPT_PATH --auto-upgrade" >"$tmp" || true
  if crontab "$tmp"; then
    echo -e "${GREEN}✅ 已移除自动更新计划任务${NC}"
  else
    echo -e "${RED}❌ 移除计划任务失败${NC}"
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

# ---------- 升级 ----------
upgrade_cli(){
  local pkg="$1" mgr="$2"
  echo "🔄 升级/安装 $pkg ..."
  local log_file
  log_file="$(mktemp)"

  case "$mgr" in
    npm)
      if npm install -g "$pkg" >"$log_file" 2>&1; then
        echo "✅ $pkg 升级/安装完成"
        rehash 2>/dev/null || true
        hash -r 2>/dev/null || true

        local cmd="" ver_cmd=""
        for entry in "${CLI_LIST[@]}"; do
            IFS='|' read -r _name _cmd _pkg _mgr _ver_cmd <<< "$entry"
            if [[ "$_pkg" == "$pkg" ]]; then cmd="$_cmd"; ver_cmd="$_ver_cmd"; break; fi
        done

        if [[ -n "$cmd" ]]; then
            local installed_ver
            installed_ver="$(get_local_version "$cmd" "$ver_cmd")"
            local latest_ver
            latest_ver="$(npm view "$pkg" version 2>/dev/null | tr -d '\n\r' || echo "-")"
            
            if [[ "$latest_ver" != "-" && "$installed_ver" != "$latest_ver" ]]; then
                echo -e "${YELLOW}⚠️  警告：当前生效版本 ($installed_ver) 与 刚安装的版本 ($latest_ver) 不一致！${NC}"
                echo "🔍 可能存在多版本冲突，检测路径："
                which -a "$cmd" 2>/dev/null || type -a "$cmd" 2>/dev/null
                echo "💡 建议：请删除优先级较高的旧版本，或调整 PATH 顺序。"
            fi
        fi
      else
        echo -e "${RED}⚠️ $pkg 升级/安装失败，详情：${NC}"
        cat "$log_file"
      fi
      ;; 
    uv)
      ensure_uv || { rm -f "$log_file"; echo -e "${BLUE}⚠️ 跳过 $pkg${NC}"; return 0; }
      if uv tool upgrade "$pkg" --python 3.13 --no-cache >"$log_file" 2>&1; then
        echo "✅ $pkg 升级完成"
      else
        # 检查是否因为未安装
        if grep -i -q "not installed" "$log_file" || grep -i -q "no tool named" "$log_file"; then
          echo -e "${BLUE}ℹ️ 检测到未安装，尝试安装 $pkg ...${NC}"
          if uv tool install "$pkg" --python 3.13 --no-cache >"$log_file" 2>&1; then
            echo "✅ $pkg 安装完成"
          else
            echo -e "${RED}⚠️ $pkg 安装失败，详情：${NC}"
            cat "$log_file"
          fi
        else
          echo -e "${RED}⚠️ $pkg 升级失败，详情：${NC}"
          cat "$log_file"
        fi
      fi
      ;; 
    *)
      echo -e "${YELLOW}⚠️ 未知管理器 $mgr${NC}"
      ;; 
  esac
  rm -f "$log_file"
}

# ---------- 卸载（顽固卸载版） ----------
uninstall_cli(){
  local pkg="$1" mgr="$2"
  echo "🗑️ 卸载 $pkg ..."
  case "$mgr" in
    npm)  
      local cmd=""
      for entry in "${CLI_LIST[@]}"; do
        IFS='|' read -r _name _cmd _pkg _mgr <<< "$entry"
        if [[ "$_pkg" == "$pkg" ]]; then cmd="$_cmd"; break; fi
      done
      [[ -z "$cmd" ]] && cmd="$(echo "$pkg" | sed 's/@.*\///' | sed 's/-cli$//')"

      npm uninstall -g "$pkg" >/dev/null 2>&1 || true
      command -v pnpm >/dev/null 2>&1 && pnpm -g remove "$pkg" >/dev/null 2>&1 || true
      command -v yarn >/dev/null 2>&1 && yarn global remove "$pkg" >/dev/null 2>&1 || true

      rehash 2>/dev/null || true
      hash -r 2>/dev/null || true

      if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ $cmd 仍在 PATH，位置：${NC}"
        (which -a "$cmd" 2>/dev/null || type -a "$cmd" 2>/dev/null || whence -a "$cmd" 2>/dev/null)

        local npm_prefix npm_bin
        npm_prefix="$(npm prefix -g 2>/dev/null || npm config get prefix 2>/dev/null)"
        npm_bin=""
        if [[ -n "$npm_prefix" ]]; then
          npm_bin="${npm_prefix%/}/bin"
          if [[ -e "$npm_bin/$cmd" ]]; then
            echo -e "${BLUE}🧹 清理 npm 全局 bin 残留：$npm_bin/$cmd${NC}"
            rm -f "$npm_bin/$cmd" 2>/dev/null || true
          fi
        fi

        local target_path real
        target_path="$(which "$cmd" 2>/dev/null || true)"
        if [ -L "$target_path" ]; then
          real="$(python3 - <<'PY'
import os,sys
p=sys.argv[1]
try:
    if os.path.islink(p):
        print(os.path.realpath(p))
    else:
        print(p)
except Exception:
    print("")
PY
"$target_path" 2>/dev/null || echo "")"
        else
          real="$target_path"
        fi

        case "$real" in
          /Applications/*.app/*)
            echo -e "${BLUE}🔗 检测到 $cmd 来自 App Bundle: $real${NC}"
            echo -e "${BLUE}🧹 移除符号链接：$target_path${NC}"
            rm -f "$target_path" 2>/dev/null || true
            local appname
            appname="$(echo "$real" | sed -n 's|/Applications/\(.*/\.app\)/.*|\1|p')"
            echo -e "💡 如需完全卸载，请删除应用本体：/Applications/$appname${NC}"
            ;; 
          *)
            echo -e "💡 如仍有残留路径，可手动删除对应文件/链接后 rehash${NC}"
            ;; 
        esac

        rehash 2>/dev/null || true
        hash -r 2>/dev/null || true

        if command -v "$cmd" >/dev/null 2>&1; then
          echo -e "${RED}⚠️ 仍检测到 $cmd 在 PATH 中。请根据上面路径手动清理。${NC}"
        else
          echo -e "${GREEN}✅ 已卸载 $pkg${NC}"
        fi
      else
        echo -e "${GREEN}✅ 已卸载 $pkg${NC}"
      fi
      ;; 
    uv)
      ensure_uv || { echo -e "${BLUE}⚠️ 跳过 $pkg${NC}"; return 0; }
      uv tool uninstall "$pkg" >/dev/null 2>&1 && echo -e "${GREEN}✅ 已卸载 $pkg${NC}" || echo -e "${RED}⚠️ 卸载失败 $pkg${NC}"
      ;; 
    *)
      echo -e "${YELLOW}⚠️ 未知管理器 $mgr${NC}"
      ;; 
  esac
}

# ---------- 展示 ----------
show_status(){
  divider
  print_table_row "No." "CLI 名称" "当前版本" "最新版本" "状态" "备注"
  divider
  local idx=1
  for entry in "${CLI_LIST[@]}"; do
    IFS='|' read -r name cmd pkg mgr ver_cmd <<< "$entry"
    local cur lat stat conflict_msg
    cur="$(get_local_version "$cmd" "$ver_cmd")"
    lat="$(get_latest_version "$pkg" "$mgr")"
    
    # 确定状态文本和颜色
    local color=""
    local status_text=""
    if [[ "$cur" == "-" ]]; then 
        status_text="未安装"
        color="$RED"
    elif [[ "$lat" == "-" ]]; then 
        status_text="未知"
        color="$YELLOW"
    elif [[ "$cur" == "$lat" ]]; then 
        status_text="最新"
        color="$GREEN"
    else 
        status_text="可升级"
        color="$YELLOW"
    fi
    
    # 检查冲突
    conflict_msg=""
    if command -v "$cmd" >/dev/null 2>&1; then
        local count
        count=$(which -a "$cmd" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$count" -gt 1 ]]; then
             conflict_msg="${RED}⚠️ 多路径冲突($count)${NC}"
        fi
    fi

    # 打印行（按显示宽度补齐，避免中文宽字符导致错位）
    print_table_row "$idx" "$name" "$cur" "$lat" "$status_text" "$conflict_msg" "$color"
    
    idx=$((idx+1))
  done
  divider
}

show_current_versions(){
  divider
  print_table_row_short "No." "CLI 名称" "当前版本"
  divider
  local idx=1
  for entry in "${CLI_LIST[@]}"; do
    IFS='|' read -r name cmd _pkg _mgr ver_cmd <<< "$entry"
    local cur
    cur="$(get_local_version "$cmd" "$ver_cmd")"
    print_table_row_short "$idx" "$name" "$cur"
    idx=$((idx+1))
  done
  divider
}

# ---------- 参数处理 ----------
case "${1:-}" in
  --version|-V)
    echo "AI CLI 管理器 v${SCRIPT_VERSION}"
    exit 0
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  --auto-upgrade)
    auto_upgrade_installed
    exit 0
    ;;
  --setup-daily)
    install_cron_job "${2:-}"
    exit 0
    ;;
  --remove-daily)
    remove_cron_job
    exit 0
    ;;
esac

# ---------- 主循环 ----------
ensure_npm # 检查 npm 状态

while true; do
  echo
  echo "🚀 AI CLI 管理器 v${SCRIPT_VERSION}"
  show_status
  echo "操作选项："
  echo "  [数字] 升级指定 CLI"
  echo "  u      升级所有可升级 CLI"
  echo "  ua     升级所有已安装 CLI（不管是否最新）"
  echo "  d      删除指定 CLI"
  echo "  da     删除全部 CLI"
  echo "  r      重新检测"
  echo "  q      退出"
  read -rp "选择操作: " choice

  case "$choice" in
    [0-9]*) 
      sel="${CLI_LIST[$((choice-1))]}"
      if [[ -n "$sel" ]]; then
        IFS='|' read -r name cmd pkg mgr _ver_cmd <<< "$sel"
        upgrade_cli "$pkg" "$mgr"
      else
        echo "❌ 无效编号"
      fi
      ;; 
    u)
      echo "🔄 升级所有可升级 CLI ..."
      for entry in "${CLI_LIST[@]}"; do
        IFS='|' read -r name cmd pkg mgr ver_cmd <<< "$entry"
        cur="$(get_local_version "$cmd" "$ver_cmd")"
        [[ "$cur" == "-" ]] && continue
        lat="$(get_latest_version "$pkg" "$mgr")"
        [[ "$lat" == "-" ]] && continue
        if [[ "$cur" != "$lat" ]]; then
          upgrade_cli "$pkg" "$mgr"
        fi
      done
      ;; 
    ua)
      echo "🔄 升级所有已安装 CLI ..."
      for entry in "${CLI_LIST[@]}"; do
        IFS='|' read -r name cmd pkg mgr ver_cmd <<< "$entry"
        cur="$(get_local_version "$cmd" "$ver_cmd")"
        [[ "$cur" == "-" ]] || upgrade_cli "$pkg" "$mgr"
      done
      ;; 
    d)
      read -rp "输入要删除的编号: " idx
      sel="${CLI_LIST[$((idx-1))]}"
      if [[ -n "$sel" ]]; then
        IFS='|' read -r name cmd pkg mgr _ver_cmd <<< "$sel"
        uninstall_cli "$pkg" "$mgr"
      else
        echo "❌ 无效编号"
      fi
      ;; 
    da)
      read -rp "⚠️ 确定删除所有 CLI？(y/n): " c
      if [[ "$c" == "y" ]]; then
        for entry in "${CLI_LIST[@]}"; do
          IFS='|' read -r _ _ pkg mgr _ver_cmd <<< "$entry"
          uninstall_cli "$pkg" "$mgr"
        done
      else
        echo "已取消。"
      fi
      ;; 
    r) : ;;  # 直接重算
    q) echo "👋 再见！"; exit 0 ;; 
    *) echo "❌ 无效选项" ;; 
  esac
done
