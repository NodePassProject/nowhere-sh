#!/usr/bin/env bash
# The self-update implementation shipped in commit d00ec90.
set -euo pipefail
SCRIPT_RAW_URL="https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh"
SCRIPT_PATH="${BASH_SOURCE[0]}"
info() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }
is_chinese() { return 1; }
update_script() {
  local tmp backup mode
  [[ -f "$SCRIPT_PATH" ]] || die "Cannot update a script run from a pipe. Download it to a file first."
  [[ -w "$SCRIPT_PATH" ]] || die "Current script is not writable: ${SCRIPT_PATH}. Run with sudo or fix permissions."
  command -v curl >/dev/null 2>&1 || die "curl is required to update the script."
  tmp="$(mktemp "${SCRIPT_PATH}.new.XXXXXX")"; trap 'rm -f "${tmp:-}"' RETURN
  is_chinese && info "正在下载最新脚本..." || info "Downloading the latest script..."
  curl -fsSL --retry 3 --connect-timeout 10 -o "$tmp" "$SCRIPT_RAW_URL"
  bash -n "$tmp" || die "Downloaded script failed syntax validation; current script was kept."
  if cmp -s "$tmp" "$SCRIPT_PATH"; then is_chinese && info "当前已是最新脚本。" || info "The deployment script is already up to date."; rm -f "$tmp"; trap - RETURN; return; fi
  mode="$(stat -c '%a' "$SCRIPT_PATH" 2>/dev/null || printf 755)"
  backup="${SCRIPT_PATH}.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "$SCRIPT_PATH" "$backup"
  mv "$tmp" "$SCRIPT_PATH"; chmod "$mode" "$SCRIPT_PATH"; trap - RETURN
  is_chinese && info "脚本已更新，备份文件：${backup}" || info "Script updated. Backup: ${backup}"
}
update_script
