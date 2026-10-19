#!/bin/bash
#
# 把常用配置同步到 ~/config-backup 并推送到 GitHub
# 由 LaunchAgent com.hezhengdong.config-backup 每小时 :30 调用，也可手动执行。
#
# 备份范围：~/.zshrc、~/.vimrc、~/.config/clash.meta/remove_hk.sh、brew 清单
# 日志：~/Library/Logs/config-backup.log

set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LC_ALL=en_US.UTF-8
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export GIT_TERMINAL_PROMPT=0

REPO="${BACKUP_REPO:-$HOME/config-backup}"
LOG="${BACKUP_LOG:-$HOME/Library/Logs/config-backup.log}"
LOCK="$REPO/.backup.lock"
BRANCH="main"

mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG"; }

cleanup() { rmdir "$LOCK" 2>/dev/null; }
trap cleanup EXIT

if ! mkdir "$LOCK" 2>/dev/null; then
  log "上一轮仍在运行，跳过本次"
  exit 0
fi

[ -d "$REPO/.git" ] || { log "仓库不存在：$REPO"; exit 1; }

# ---- 1. 拷贝配置文件（保持路径镜像）----
copy_file() {
  local src="$1" rel="$2"
  if [ ! -f "$src" ]; then
    log "跳过（源文件不存在）：$src"
    return 0
  fi
  mkdir -p "$REPO/$(dirname "$rel")"
  cp -f "$src" "$REPO/$rel"
}

copy_file "$HOME/.zshrc" "home/.zshrc"
copy_file "$HOME/.vimrc" "home/.vimrc"
copy_file "$HOME/.config/clash.meta/remove_hk.sh" "home/.config/clash.meta/remove_hk.sh"

# ---- 2. 生成 brew 清单（排序，避免顺序抖动造成假变更）----
brew leaves 2>>"$LOG" | sort >"$REPO/inventory/brew-leaves.txt" || log "brew leaves 执行失败"
brew list --cask 2>>"$LOG" | sort >"$REPO/inventory/brew-casks.txt" || log "brew list --cask 执行失败"

# ---- 3. 提交前扫描，命中高置信度密钥就中止 ----
if grep -rIqE 'ghp_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' "$REPO/home"; then
  log "检测到疑似密钥，已中止本次提交，请人工检查"
  exit 1
fi

cd "$REPO" || exit 1

# ---- 4. 判断是否有变化或未推送的提交 ----
git add -A
AHEAD=0
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  AHEAD=$(git rev-list --count "origin/$BRANCH..HEAD")
fi

if git diff --cached --quiet && [ "$AHEAD" -eq 0 ]; then
  log "无变化"
  exit 0
fi

if ! git diff --cached --quiet; then
  CHANGED=$(git diff --cached --name-only | tr '\n' ' ')
  git commit -q -m "backup: $(date '+%Y-%m-%d %H:%M')" -m "$CHANGED" || {
    log "提交失败"
    exit 1
  }
  log "已提交：$CHANGED"
fi

# ---- 5. 推送 ----
if git push -q origin "HEAD:$BRANCH" >>"$LOG" 2>&1; then
  log "已推送 origin/$BRANCH"
else
  log "推送失败，本地提交保留，下次运行会重试"
  exit 1
fi
