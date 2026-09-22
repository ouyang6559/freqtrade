#!/usr/bin/env bash
set -u

RUN=0
[[ "${1:-}" == "--yes" ]] && RUN=1

# 备份目录
BACKUP="$HOME/Desktop/opencode-cleanup-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

log() { printf '\033[1;34m[clean]\033[0m %s\n' "$*"; }
run() {
  if [[ $RUN -eq 1 ]]; then
    log "EXEC: $*"
    eval "$@"
  else
    log "DRY : $*"
  fi
}

# 1) 停进程 -------------------------------------------------------------------
log "=== 1. 停止 OpenCode / bun sidecar 进程 ==="
for p in opencode opencode-daemon bun; do
  run "pkill -f '$p' 2>/dev/null || true"
done

# 2) 包管理器：npm / pnpm / yarn / bun 全局卸载 -------------------------------
log "=== 2. 全局包管理器卸载 opencode / omo ==="

# npm（官方包名通常是 opencode-ai，有些旧版用 opencode）
run "npm uninstall -g opencode-ai 2>/dev/null || true"
run "npm uninstall -g opencode 2>/dev/null || true"
run "npm uninstall -g oh-my-openagent 2>/dev/null || true"
run "npm uninstall -g oh-my-opencode 2>/dev/null || true"
run "npm cache clean --force 2>/dev/null || true"

# pnpm
run "pnpm uninstall -g opencode-ai 2>/dev/null || true"
run "pnpm uninstall -g opencode 2>/dev/null || true"
run "pnpm uninstall -g oh-my-openagent 2>/dev/null || true"
run "pnpm uninstall -g oh-my-opencode 2>/dev/null || true"
run "pnpm store prune 2>/dev/null || true"

# yarn
run "yarn global remove opencode-ai 2>/dev/null || true"
run "yarn global remove opencode 2>/dev/null || true"

# bun 全局（bunx 是临时执行器，不需卸载；只卸全局包）
run "bun uninstall -g opencode-ai 2>/dev/null || true"
run "bun remove -g opencode-ai 2>/dev/null || true"
run "bun uninstall -g opencode 2>/dev/null || true"
run "bun remove -g opencode 2>/dev/null || true"
run "bun uninstall -g oh-my-openagent 2>/dev/null || true"
run "bun uninstall -g oh-my-opencode 2>/dev/null || true"
# bun 全局安装目录清理
run "rm -rf \"$HOME/.bun/install/global/node_modules/opencode-ai\" 2>/dev/null || true"
run "rm -rf \"$HOME/.bun/install/global/node_modules/opencode\" 2>/dev/null || true"
run "rm -rf \"$HOME/.bun/install/global/node_modules/oh-my-openagent\" 2>/dev/null || true"
run "rm -rf \"$HOME/.bun/install/global/node_modules/oh-my-opencode\" 2>/dev/null || true"

# 3) Homebrew ----------------------------------------------------------------
log "=== 3. Homebrew 卸载 ==="
run "brew uninstall --force opencode 2>/dev/null || true"
run "brew uninstall --force opencode/tap/opencode 2>/dev/null || true"
run "brew cleanup 2>/dev/null || true"

# 4) 官方 uninstall 命令 + 脚本安装目录 --------------------------------------
log "=== 4. opencode uninstall + 脚本安装目录 ==="
run "opencode uninstall 2>/dev/null <<< '' || true"   # 官方交互卸载，能跑就跑
run "rm -rf \"$HOME/.opencode/bin\" 2>/dev/null || true"
run "rm -rf \"$HOME/.opencode\" 2>/dev/null || true"

# 常见二进制位置
for b in /usr/local/bin/opencode /opt/homebrew/bin/opencode "$HOME/.local/bin/opencode" "$HOME/bin/opencode"; do
  run "rm -f '$b' 2>/dev/null || true"
done

# 5) 桌面版 App --------------------------------------------------------------
log "=== 5. OpenCode Desktop App ==="
run "rm -rf /Applications/OpenCode.app 2>/dev/null || true"
run "rm -rf /Applications/OpenCode\\ Desktop.app 2>/dev/null || true"
# 桌面支持数据（按你前面排障，常见在 ai.opencode.desktop）
run "rm -rf \"$HOME/Library/Application Support/ai.opencode.desktop\" 2>/dev/null || true"
run "rm -rf \"$HOME/Library/Application Support/OpenCode\" 2>/dev/null || true"
run "rm -rf \"$HOME/Library/Caches/ai.opencode.desktop\" 2>/dev/null || true"
run "rm -rf \"$HOME/Library/Caches/opencode\" 2>/dev/null || true"
run "rm -rf \"$HOME/Library/Logs/ai.opencode.desktop\" 2>/dev/null || true"
# 可能的前台/后台 launch agent
run "rm -f \"$HOME/Library/LaunchAgents\"/*opencode* 2>/dev/null || true"

# 6) OpenCode 配置 / 数据 / 日志 / 缓存 -------------------------------------
log "=== 6. OpenCode 配置/数据/日志/缓存 ==="
run "rm -rf \"$HOME/.config/opencode\" 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode\" 2>/dev/null || true"
run "rm -rf \"$HOME/.local/share/opencode\" 2>/dev/null || true"
run "rm -rf \"$HOME/.local/state/opencode\" 2>/dev/null || true"
run "rm -rf \"$HOME/Library/Caches/opencode\" 2>/dev/null || true"

# 7) oh-my-openagent / oh-my-opencode 全清 -----------------------------------
log "=== 7. OMO / OMO-old 插件全清 ==="
# 插件沙箱（不同版本布局都覆盖）
run "rm -rf \"$HOME/.cache/opencode/packages/oh-my-openagent@latest\" 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode/packages/oh-my-opencode@latest\" 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode/packages/oh-my-openagent@\"* 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode/packages/oh-my-opencode@\"* 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode/npm/oh-my-openagent\"* 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode/npm/oh-my-opencode\"* 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode/node_modules/oh-my-openagent\" 2>/dev/null || true"
run "rm -rf \"$HOME/.cache/opencode/node_modules/oh-my-opencode\" 2>/dev/null || true"
# 统一配置与旧配置
run "rm -f \"$HOME/.omo/omo.jsonc\" \"$HOME/.omo/omo.json\" 2>/dev/null || true"
run "rm -rf \"$HOME/.omo\" 2>/dev/null || true"
run "rm -f \"$HOME/.config/opencode/oh-my-openagent.jsonc\" \"$HOME/.config/opencode/oh-my-openagent.json\" 2>/dev/null || true"
run "rm -f \"$HOME/.config/opencode/oh-my-opencode.jsonc\" \"$HOME/.config/opencode/oh-my-opencode.json\" 2>/dev/null || true"
# 全局 local 插件目录
run "rm -rf \"$HOME/.config/opencode/plugins/oh-my-openagent\" 2>/dev/null || true"
run "rm -rf \"$HOME/.config/opencode/plugins/oh-my-opencode\" 2>/dev/null || true"
# bunx 临时目录里可能残留
run "rm -rf \"$HOME/Library/Caches/bunx\" 2>/dev/null || true"
run "rm -rf /tmp/bunx-*oh-my-openagent* /tmp/bunx-*oh-my-opencode* 2>/dev/null || true"

# 8) 项目级残留（默认不删，避免误删代码；用 --projects 才清） ----------------
if [[ "${1:-}" == "--projects" || "${2:-}" == "--projects" ]]; then
  log "=== 8. 项目级 .opencode / .omo 清理（仅当前目录向下）==="
  run "find . -type d \( -name .opencode -o -name .omo \) -prune -exec rm -rf {} + 2>/dev/null || true"
  run "find . -type f \( -name 'oh-my-openagent.json*' -o -name 'oh-my-opencode.json*' \) -delete 2>/dev/null || true"
else
  log "=== 8. 跳过项目级 .opencode/.omo（要清加 --projects）==="
fi

# 9) 校验 --------------------------------------------------------------------
log "=== 9. 校验 ==="
if command -v opencode >/dev/null 2>&1; then
  log "仍检测到 opencode: $(command -v opencode)"
else
  log "opencode 命令已不可见（which 为空）"
fi
log "备份建议：重装前重要配置已可手动存到 $BACKUP"

log "完成。RUN=$RUN (0=dry-run, 1=真实删除)"