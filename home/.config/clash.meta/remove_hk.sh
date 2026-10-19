#!/bin/bash
#
# 丛雨云订阅 -> ClashX Meta 可用配置（丛雨云_nohk.yaml）
#
# 做的事：
#   1. 仅从「♻️ 自动选择」组中剔除港/台/失效提示节点，其它分组与 proxies 原样保留
#   2. 将 dns 段整段替换为指定配置（不使用任何国内 DNS）
#   3. 覆盖前做完整性校验，校验不过就不动旧文件
#
# 由 cron 每天 12:00 调用，也可手动执行。

set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LC_ALL=en_US.UTF-8

DIR="/Users/hezhengdong/.config/clash.meta"
SRC="$DIR/丛雨云.yaml"
DEST="$DIR/丛雨云_nohk.yaml"
TMP="$DIR/.temp_nohk.$$.yaml"
ERR="$DIR/.remove_hk.$$.err"
LOCK="$DIR/.remove_hk.lock"
LOG="$DIR/remove_hk.log"

AUTO_GROUP="♻️ 自动选择"
# 港/台及常见变体写法；不含任何真实节点（如 🇯🇵全部超时请更新订阅 是可用节点，不能误伤）
EXCLUDE_RE='Hong ?Kong|香港|🇭🇰|\bHK\b|Taiwan|臺灣|台湾|🇹🇼|\bTW\b|全部超时请检查系统时间|请开启自动更新订阅'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG"; }

cleanup() {
  rm -f "$TMP" "$ERR"
  rmdir "$LOCK" 2>/dev/null
}
trap cleanup EXIT

# 并发锁：上一轮没跑完就跳过
if ! mkdir "$LOCK" 2>/dev/null; then
  log "上一轮仍在运行，跳过本次"
  exit 0
fi

if [ ! -s "$SRC" ]; then
  log "源文件不存在或为空：$SRC，跳过"
  exit 1
fi

# 处理：dns 整段替换为指定配置 + 只过滤自动选择组
if ! yq -e "
  .dns = {} |
  .dns.enable = true |
  .dns.listen = \"0.0.0.0:8853\" |
  .dns.ipv6 = false |
  .dns.default-nameserver = [\"1.1.1.1\", \"8.8.8.8\"] |
  .dns.nameserver = [\"1.1.1.1\", \"8.8.8.8\"] |
  .dns.fallback = [\"1.1.1.1\", \"8.8.8.8\"] |
  (.proxy-groups[] | select(.name == \"$AUTO_GROUP\") | .proxies) |= filter(test(\"$EXCLUDE_RE\") | not)
" "$SRC" >"$TMP" 2>"$ERR"; then
  log "yq 处理失败，旧配置保持不变：$(tr '\n' ' ' <"$ERR" | cut -c1-300)"
  exit 1
fi

# ---- 完整性校验 ----
fail() { log "校验失败：$1，旧配置保持不变"; rm -f "$TMP"; exit 1; }

[ -s "$TMP" ] || fail "输出为空"

# 输出体积不该比源文件小太多（防订阅返回错误页/半截文件）
SRC_SIZE=$(wc -c <"$SRC")
TMP_SIZE=$(wc -c <"$TMP")
[ "$TMP_SIZE" -gt $((SRC_SIZE / 2)) ] || fail "输出仅 ${TMP_SIZE}B，源文件 ${SRC_SIZE}B，疑似内容残缺"

# proxies / 分组数量必须与源一致（只允许成员变动，不允许结构损坏）
SRC_PROXIES=$(yq '.proxies | length' "$SRC" 2>/dev/null)
TMP_PROXIES=$(yq '.proxies | length' "$TMP" 2>/dev/null)
[ "$SRC_PROXIES" = "$TMP_PROXIES" ] || fail "proxies 数量 $SRC_PROXIES -> $TMP_PROXIES"

SRC_GROUPS=$(yq '.proxy-groups | length' "$SRC" 2>/dev/null)
TMP_GROUPS=$(yq '.proxy-groups | length' "$TMP" 2>/dev/null)
[ "$SRC_GROUPS" = "$TMP_GROUPS" ] || fail "proxy-groups 数量 $SRC_GROUPS -> $TMP_GROUPS"

# 自动选择组必须存在、非空、且已无港台残留
LEFT=$(yq "[.proxy-groups[] | select(.name == \"$AUTO_GROUP\") | .proxies | length] | .[0] // 0" "$TMP" 2>/dev/null)
[ "${LEFT:-0}" -gt 0 ] || fail "自动选择组为空或不存在"
RESIDUE=$(yq "[.proxy-groups[] | select(.name == \"$AUTO_GROUP\") | .proxies[] | select(test(\"$EXCLUDE_RE\"))] | length" "$TMP" 2>/dev/null)
[ "${RESIDUE:-1}" -eq 0 ] || fail "自动选择组仍残留 $RESIDUE 个港台节点"

yq '.dns.enable' "$TMP" 2>/dev/null | grep -qx true || fail "dns 段写入失败"

# ---- 对比与替换 ----
if [ -f "$DEST" ] && cmp -s "$TMP" "$DEST"; then
  log "配置未发生变化，无需更新（自动选择组 $LEFT 个节点）"
  exit 0
fi

mv -f "$TMP" "$DEST"
log "配置已更新：自动选择组剔除港台后剩 $LEFT 个节点，dns 已按指定值整段替换"