# AI CLI 管理器（v1.0.0）

一个跨平台的 zsh/bash 工具，用于**检测、升级、卸载**常见 AI Coding CLI：Qoder、Codex, Gemini, Cline CLI, Claude Code, Qwen, Grok, IFlow, Kimi。

![Demo.png](demo.png)

---

## ✨ 功能

* 启动即检测本地版本 + 远端最新版本
* **状态高亮**：最新（绿）、可升级（黄）、未安装（红）、冲突（警告）
* **智能安装**：自动检测 npm/uv 环境，缺失时引导安装
* 升级单个 / 升级所有可升级 / 升级所有已安装
* 卸载单个 / 卸载全部（含顽固残留清理）
* Kimi 使用 `uv tool`，并显式 `--python 3.13`
* 支持每日定时自动升级已安装 CLI（自选时间 `HH:MM`，默认 03:00，`--setup-daily [HH:MM]` 写入 crontab，可随时 `--remove-daily` 移除）

---

## 🔧 安装与运行

### 🚀 自动安装（推荐）

可以通过以下命令一键安装到系统（默认安装为 `ai-cli-manager` 命令）：

```bash
# 请将 <YOUR_GITHUB_USER> 替换为实际的 GitHub 用户名
curl -sSL https://raw.githubusercontent.com/<YOUR_GITHUB_USER>/manage_ai_clis/main/install.sh | bash
```

安装完成后，直接在终端输入即可启动：
```bash
ai-cli-manager
```

查看版本号：
```bash
ai-cli-manager --version
```

配置每日自动升级（写入当前用户 crontab，每天 03:00 执行 `--auto-upgrade`）：
```bash
ai-cli-manager --setup-daily           # 默认 03:00
ai-cli-manager --setup-daily 05:30     # 自定义时间
```

取消每日自动升级：
```bash
ai-cli-manager --remove-daily
```
手动触发一次自动升级（仅升级有新版本的已安装 CLI，可用于自定义计划任务）：
```bash
ai-cli-manager --auto-upgrade
```

### 🐌 手动运行

如果不想安装到系统路径：

```bash
chmod +x manage_ai_clis.sh
./manage_ai_clis.sh
```

查看版本号：
```bash
./manage_ai_clis.sh --version
```

自动升级相关同上，使用脚本路径调用：
```bash
./manage_ai_clis.sh --setup-daily
./manage_ai_clis.sh --remove-daily
./manage_ai_clis.sh --auto-upgrade
```

---

## 🧭 菜单

```
[数字] 升级指定 CLI  
u      升级所有可升级 CLI  
ua     升级所有已安装 CLI（不管是否最新）  
d      删除指定 CLI  
da     删除全部 CLI  
r      重新检测  
q      退出
```

---

## 🧱 各 CLI 管理方式 & 官方链接

| CLI 名称      | 命令       | 包名                            | 管理器 | 官方网址                                                                           | GitHub 链接                                                                                  |
| ----------- | -------- | ----------------------------- | --- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| Qoder       | `qodercli` | `@qoder-ai/qodercli`          | npm | [https://qoder.com/cli](https://qoder.com/cli)                                 | [https://github.com/qoder-ai/qodercli](https://github.com/qoder-ai/qodercli)               |
| Codex       | `codex`  | `@openai/codex`               | npm | [https://openai.com/codex](https://openai.com/codex)                           | [https://github.com/openai/codex](https://github.com/openai/codex)                         |
| Gemini      | `gemini` | `@google/gemini-cli`          | npm | [https://gemini.google/cli](https://gemini.google/cli)                         | [https://github.com/google/gemini-cli](https://github.com/google/gemini-cli)               |
| Cline CLI   | `cline`  | `cline`                       | npm | [https://docs.cline.bot/cline-cli/overview](https://docs.cline.bot/cline-cli/overview) | - |
| Claude Code | `claude` | `@anthropic-ai/claude-code`   | npm | [https://www.anthropic.com/claude-code](https://www.anthropic.com/claude-code) | [https://github.com/anthropic-ai/claude-code](https://github.com/anthropic-ai/claude-code) |
| Qwen Code   | `qwen`   | `@qwen-code/qwen-code@latest` | npm | [https://github.com/QwenLM/qwen-code](https://github.com/QwenLM/qwen-code)     | [https://github.com/QwenLM/qwen-code](https://github.com/QwenLM/qwen-code)                 |
| Grok        | `grok`   | `@vibe-kit/grok-cli`          | npm | [https://grok.ai/cli](https://grok.ai/cli)                                     | [https://github.com/vibe-kit/grok-cli](https://github.com/vibe-kit/grok-cli)               |
| IFlow CLI   | `iflow`  | `@iflow-ai/iflow-cli`         | npm | [https://iflow.ai/cli](https://iflow.ai/cli)                                   | [https://github.com/iflow-ai/iflow-cli](https://github.com/iflow-ai/iflow-cli)             |
| Kimi CLI    | `kimi`   | `kimi-cli` (PyPI)             | uv  | [https://kimi.com/coding/docs/kimi-cli](https://kimi.com/coding/docs/kimi-cli) | [https://github.com/MoonshotAI/kimi-cli](https://github.com/MoonshotAI/kimi-cli)           |

*(注：表中“包名”按安装命令展示，管理器指使用 npm 或 uv 安装/升级/卸载)*

---

## ❓ 常见问题 (FAQ)

### 1. 自动安装时提示 `curl: command not found` 或 `wget: command not found`
**原因**：您的系统未安装下载工具。
**解决方案**：
*   **macOS**: 一般自带 curl。如果缺失，请安装 Homebrew 后运行 `brew install curl`。
*   **Ubuntu/Debian**: 运行 `sudo apt-get install curl`。
*   **CentOS/RHEL**: 运行 `sudo yum install curl`。

### 2. 运行脚本提示 `npm: command not found`
**原因**：大部分 AI CLI 依赖 Node.js 环境，脚本启动时会检测 npm。
**解决方案**：
*   **推荐**: 访问 [Node.js 官网](https://nodejs.org/) 下载并安装 LTS 版本。
*   **macOS (Homebrew)**: `brew install node`
*   **Linux**: 使用 nvm 安装（推荐）或包管理器安装。

### 3. 列表中显示 `⚠️ 多路径冲突`
**原因**：同一个命令（如 `qodercli`）在您的系统路径（PATH）中存在多个版本（例如一个在 `/opt/homebrew/bin`，一个在 `~/.local/bin`）。这会导致升级后版本看起来“没变”，因为系统优先使用了旧的那个。
**解决方案**：
1.  运行 `which -a <command>` 查看所有路径（例如 `which -a qodercli`）。
2.  删除不需要的那个旧版本（例如 `rm /Users/xxx/.local/bin/qodercli`）。
3.  运行 `hash -r` 刷新缓存。

### 4. 安装完 `ai-cli-manager` 后提示 `command not found`
**原因**：自动安装脚本将工具放在了 `~/.local/bin`，但该目录不在您的 PATH 环境变量中。
**解决方案**：
将以下内容添加到您的 shell 配置文件（`~/.zshrc` 或 `~/.bashrc`）末尾：
```bash
export PATH="$HOME/.local/bin:$PATH"
```
然后运行 `source ~/.zshrc`（或对应文件）生效。

### 5. Kimi CLI 安装/升级失败
**原因**：Kimi CLI 使用 `uv` 管理且依赖 Python 3.13。
**解决方案**：
*   脚本会自动尝试安装 `uv`。如果失败，请手动安装：`curl -LsSf https://astral.sh/uv/install.sh | sh`
*   确保您的网络可以访问 PyPI。脚本已内置 User-Agent 模拟以规避部分防火墙问题，但网络连接仍需您保证。
