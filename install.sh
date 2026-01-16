#!/usr/bin/env bash
# AI CLI 管理器自动安装脚本
# 用法: curl -sSL https://raw.githubusercontent.com/<USER>/<REPO>/main/install.sh | bash

set -e

# --- 配置区 (请在上传前修改这里，或保持结构一致) ---
GITHUB_REPO="<YOUR_GITHUB_USER>/manage_ai_clis"
SCRIPT_NAME="manage_ai_clis.sh"
BIN_NAME="ai-cli-manager"  # 安装后的命令名称
INSTALL_DIR="$HOME/.local/bin"
BRANCH="main"
# ------------------------------------------------

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 开始安装 AI CLI 管理器...${NC}"

# 1. 确定下载地址
DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${BRANCH}/${SCRIPT_NAME}"

# 2. 准备安装目录
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}📂 创建目录 $INSTALL_DIR ...${NC}"
    mkdir -p "$INSTALL_DIR"
fi

# 3. 下载脚本
echo -e "${BLUE}⬇️  正在从 GitHub 下载...${NC}"
echo "源地址: $DOWNLOAD_URL"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/$BIN_NAME"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$INSTALL_DIR/$BIN_NAME" "$DOWNLOAD_URL"
else
    echo -e "${RED}❌ 错误: 未找到 curl 或 wget，无法下载。${NC}"
    exit 1
fi

# 4. 赋予权限
if [ -f "$INSTALL_DIR/$BIN_NAME" ]; then
    chmod +x "$INSTALL_DIR/$BIN_NAME"
    version="$(grep -E '^SCRIPT_VERSION=' "$INSTALL_DIR/$BIN_NAME" | head -n1 | sed -E 's/[^0-9.]+//g')"
else
    echo -e "${RED}❌ 下载失败，未找到文件。请检查网络或仓库地址。${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 安装完成！${NC}"
echo -e "程序位置: ${INSTALL_DIR}/${BIN_NAME}"
if [ -n "$version" ]; then
    echo -e "版本: v${version}"
fi

# 5. 检查 PATH
case ":$PATH:" in
    *":$INSTALL_DIR:"*) 
        echo -e "${GREEN}🚀 您现在可以在终端直接输入 '$BIN_NAME' 来启动管理器了！${NC}"
        ;;
    *)
        echo -e "${YELLOW}⚠️  警告: $INSTALL_DIR 不在您的 PATH 环境变量中。${NC}"
        echo "请将以下内容添加到您的 Shell 配置文件中 (例如 ~/.zshrc 或 ~/.bashrc):"
        echo -e "${BLUE}export PATH=\"\\$HOME/.local/bin:\\$PATH\"${NC}" 
        echo "然后执行 'source ~/.zshrc' (或对应文件) 使其生效。"
        ;;
esac
