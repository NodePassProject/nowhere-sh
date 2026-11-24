#!/usr/bin/env bash
set -euo pipefail

REPO="NodePassProject/Nowhere"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh"
SCRIPT_VERSION="2026.11.24"
SCRIPT_UPDATE_AVAILABLE_VERSION=""
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if command -v readlink >/dev/null 2>&1; then SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || printf '%s' "$SCRIPT_PATH")"; fi
SERVICE_NAME="nowhere"
BIN_PATH="/usr/local/bin/nowhere"
CONFIG_DIR="/etc/nowhere"
CONFIG_FILE="${CONFIG_DIR}/nowhere.env"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_BACKEND=systemd
if [[ -f /etc/alpine-release ]] || { [[ ! -d /run/systemd/system ]] && command -v rc-service >/dev/null 2>&1; }; then
  SERVICE_BACKEND=openrc
  SERVICE_FILE="/etc/init.d/${SERVICE_NAME}"
fi

DEFAULT_VERSION="v3.1.0"
TLS_EGRESS_MIN_VERSION="v3.3.0"
CIPHER_MIN_VERSION="v3.4.0"
NW2_LTS_VERSION="v2.2.1"
DEFAULT_PORT="2077"
DEFAULT_TCP_CARRIER="tcp"
DEFAULT_UDP_CARRIER="udp"
DEFAULT_CLIENT="anywhere"
DEFAULT_TLS="1"
DEFAULT_LOG="info"
DEFAULT_MORPH="0"
DEFAULT_MORPH_TCP_PRELUDE="full8"
DEFAULT_MUX="0"
DEFAULT_TRANSPORT_MEMORY_PROFILE="throughput"
[[ "$SERVICE_BACKEND" != openrc ]] || DEFAULT_TRANSPORT_MEMORY_PROFILE=memory
DEFAULT_MIX_FALLBACK_TIMEOUT="1s"
DEFAULT_SOCKS="none"
DEFAULT_VECTOR_SOCKS="127.0.0.1:1080"
DEFAULT_SNI="none"
DEFAULT_PIN="none"
DEFAULT_TELEMETRY_INTERVAL="1s"

ASSUME_YES=0
SKIP_JQ=0
SKIP_QRENCODE=0
VERSION_EXPLICIT=0
KEY_EXPLICIT=0
[[ ${NOWHERE_KEY+x} ]] && KEY_EXPLICIT=1
ALLOW_PROTOCOL_BREAKING_UPGRADE=0
ALLOW_PRELUDE_BREAKING_UPGRADE=0
ROLE_EXPLICIT=0
OUT_EXPLICIT=0
PUBLIC_HOST_EXPLICIT=0
LISTEN_HOST_EXPLICIT=0
TCP_CARRIER_EXPLICIT=0
TCP_PORT_EXPLICIT=0
UDP_CARRIER_EXPLICIT=0
UDP_PORT_EXPLICIT=0
[[ ${NOWHERE_PUBLIC_HOST+x} ]] && PUBLIC_HOST_EXPLICIT=1
[[ ${NOWHERE_LISTEN_HOST+x} ]] && LISTEN_HOST_EXPLICIT=1
[[ ${NOWHERE_TCP_CARRIER+x} ]] && TCP_CARRIER_EXPLICIT=1
[[ ${NOWHERE_TCP_PORT+x} ]] && TCP_PORT_EXPLICIT=1
[[ ${NOWHERE_UDP_CARRIER+x} ]] && UDP_CARRIER_EXPLICIT=1
[[ ${NOWHERE_UDP_PORT+x} ]] && UDP_PORT_EXPLICIT=1
DIAL_EXPLICIT=0
[[ ${NOWHERE_DIAL+x} ]] && DIAL_EXPLICIT=1
DIAL4_EXPLICIT=0
DIAL6_EXPLICIT=0
[[ ${NOWHERE_DIAL4+x} ]] && DIAL4_EXPLICIT=1
[[ ${NOWHERE_DIAL6+x} ]] && DIAL6_EXPLICIT=1
ACTION="${1:-menu}"
[[ $# -eq 0 ]] || shift
PROBE_TARGET=""
if [[ "$ACTION" == probe && $# -gt 0 && "$1" != -* ]]; then PROBE_TARGET="$1"; shift; fi
FINGERPRINT_URL=""
if [[ "$ACTION" == fingerprint && $# -gt 0 && "$1" != -* ]]; then FINGERPRINT_URL="$1"; shift; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1; shift ;;
    --skip-jq) SKIP_JQ=1; shift ;;
    --skip-qrencode) SKIP_QRENCODE=1; shift ;;
    --lang) NOWHERE_LANG="${2:?missing --lang value}"; shift 2 ;;
    --version) NOWHERE_VERSION="${2:?missing --version value}"; VERSION_EXPLICIT=1; shift 2 ;;
    --role) NOWHERE_ROLE="${2:?missing --role value}"; ROLE_EXPLICIT=1; shift 2 ;;
    --allow-protocol-breaking-upgrade) ALLOW_PROTOCOL_BREAKING_UPGRADE=1; shift ;;
    --allow-prelude-breaking-upgrade) ALLOW_PRELUDE_BREAKING_UPGRADE=1; shift ;;
    --out) NOWHERE_OUT="${2:?missing --out value}"; OUT_EXPLICIT=1; shift 2 ;;
    --out-socks) NOWHERE_OUT_SOCKS="${2:?missing --out-socks value}"; shift 2 ;;
    --egress-portal-host) NOWHERE_EGRESS_PORTAL_HOST="${2:?missing --egress-portal-host value}"; shift 2 ;;
    --egress-portal-carrier|--egress-portal-udp-carrier) NOWHERE_EGRESS_PORTAL_CARRIER="${2:?missing Egress Portal carrier}"; shift 2 ;;
    --egress-portal-port|--egress-portal-udp-port) NOWHERE_EGRESS_PORTAL_PORT="${2:?missing Egress Portal port}"; shift 2 ;;
    --egress-sni) NOWHERE_EGRESS_SNI="${2:?missing --egress-sni value}"; shift 2 ;;
    --egress-pin) NOWHERE_EGRESS_PIN="${2:?missing --egress-pin value}"; shift 2 ;;
    --client) NOWHERE_CLIENT="${2:?missing --client value}"; shift 2 ;;
    --key) NOWHERE_KEY="${2:?missing --key value}"; KEY_EXPLICIT=1; shift 2 ;;
    --public-host) NOWHERE_PUBLIC_HOST="${2:?missing --public-host value}"; PUBLIC_HOST_EXPLICIT=1; shift 2 ;;
    --anywhere-sni) NOWHERE_ANYWHERE_SNI="${2:?missing --anywhere-sni value}"; shift 2 ;;
    --listen-host) NOWHERE_LISTEN_HOST="${2:?missing --listen-host value}"; LISTEN_HOST_EXPLICIT=1; shift 2 ;;
    --tcp-carrier) NOWHERE_TCP_CARRIER="${2:?missing --tcp-carrier value}"; TCP_CARRIER_EXPLICIT=1; shift 2 ;;
    --tcp-port) NOWHERE_TCP_PORT="${2:?missing --tcp-port value}"; TCP_PORT_EXPLICIT=1; shift 2 ;;
    --udp-carrier) NOWHERE_UDP_CARRIER="${2:?missing --udp-carrier value}"; UDP_CARRIER_EXPLICIT=1; shift 2 ;;
    --udp-port) NOWHERE_UDP_PORT="${2:?missing --udp-port value}"; UDP_PORT_EXPLICIT=1; shift 2 ;;
    --tls) NOWHERE_TLS="${2:?missing --tls value}"; shift 2 ;;
    --crt|--cert) NOWHERE_CRT="${2:?missing --crt value}"; shift 2 ;;
    --tls-key) NOWHERE_TLS_KEY="${2:?missing --tls-key value}"; shift 2 ;;
    --morph) NOWHERE_MORPH="${2:?missing --morph value}"; shift 2 ;;
    --cipher) NOWHERE_CIPHER="${2:?missing --cipher value}"; shift 2 ;;
    --morph-tcp-prelude) NOWHERE_MORPH_TCP_PRELUDE="${2:?missing --morph-tcp-prelude value}"; shift 2 ;;
    --rate) NOWHERE_RATE="${2:?missing --rate value}"; shift 2 ;;
    --etar) NOWHERE_ETAR="${2:?missing --etar value}"; shift 2 ;;
    --dial) NOWHERE_DIAL="${2:?missing --dial value}"; DIAL_EXPLICIT=1; shift 2 ;;
    --dial4) NOWHERE_DIAL4="${2:?missing --dial4 value}"; DIAL4_EXPLICIT=1; shift 2 ;;
    --dial6) NOWHERE_DIAL6="${2:?missing --dial6 value}"; DIAL6_EXPLICIT=1; shift 2 ;;
    --socks) NOWHERE_SOCKS="${2:?missing --socks value}"; shift 2 ;;
    --next) NOWHERE_NEXT="${2:?missing --next value}"; shift 2 ;;
    --next-up) NOWHERE_NEXT_UP="${2:?missing --next-up value}"; shift 2 ;;
    --next-down) NOWHERE_NEXT_DOWN="${2:?missing --next-down value}"; shift 2 ;;
    --next-mux) NOWHERE_NEXT_MUX="${2:?missing --next-mux value}"; shift 2 ;;
    --next-sni) NOWHERE_NEXT_SNI="${2:?missing --next-sni value}"; shift 2 ;;
    --next-pin) NOWHERE_NEXT_PIN="${2:?missing --next-pin value}"; shift 2 ;;
    --vector-up) NOWHERE_VECTOR_UP="${2:?missing --vector-up value}"; shift 2 ;;
    --vector-down) NOWHERE_VECTOR_DOWN="${2:?missing --vector-down value}"; shift 2 ;;
    --mux) NOWHERE_VECTOR_MUX="${2:?missing --mux value}"; shift 2 ;;
    --vector-socks) NOWHERE_VECTOR_SOCKS="${2:?missing --vector-socks value}"; shift 2 ;;
    --vector-rate) NOWHERE_VECTOR_RATE="${2:?missing --vector-rate value}"; shift 2 ;;
    --vector-etar) NOWHERE_VECTOR_ETAR="${2:?missing --vector-etar value}"; shift 2 ;;
    --vector-log) NOWHERE_VECTOR_LOG="${2:?missing --vector-log value}"; shift 2 ;;
    --sni) NOWHERE_VECTOR_SNI="${2:?missing --sni value}"; shift 2 ;;
    --pin) NOWHERE_VECTOR_PIN="${2:?missing --pin value}"; shift 2 ;;
    --log) NOWHERE_LOG="${2:?missing --log value}"; shift 2 ;;
    --transport-memory-profile) NOWHERE_TRANSPORT_MEMORY_PROFILE="${2:?missing --transport-memory-profile value}"; shift 2 ;;
    --mix-fallback-timeout) NOWHERE_MIX_FALLBACK_TIMEOUT="${2:?missing --mix-fallback-timeout value}"; shift 2 ;;
    --telemetry-interval) NOWHERE_TELEMETRY_INTERVAL="${2:?missing --telemetry-interval value}"; shift 2 ;;
    --target) [[ "$ACTION" == probe ]] || { printf '%s\n' "--target is only valid with the probe command." >&2; exit 1; }; [[ -z "$PROBE_TARGET" ]] || { printf '%s\n' "Specify the probe target only once." >&2; exit 1; }; [[ $# -ge 2 ]] || { printf '%s\n' "Missing --target value." >&2; exit 1; }; PROBE_TARGET="$2"; shift 2 ;;
    -h|--help) ACTION="help"; shift ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

info() { printf '\033[1;34m[Nowhere]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[Warn]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[Error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Nowhere VPS deployment and management script.

Usage:
  sudo bash nowhere-vps.sh
  sudo bash nowhere-vps.sh install [--yes] [options]
  sudo bash nowhere-vps.sh install-vector [--yes] [options]
  sudo bash nowhere-vps.sh install-egress [--yes] [options]
  sudo bash nowhere-vps.sh configure [options]
  sudo bash nowhere-vps.sh update [--version v3.1.0 or v2.2.1]
  sudo bash nowhere-vps.sh update-script
  sudo bash nowhere-vps.sh versions
  sudo bash nowhere-vps.sh start|stop|restart|status|telemetry|logs|link|fingerprint|uninstall
  sudo bash nowhere-vps.sh tui                          (NW2 only)
  sudo bash nowhere-vps.sh generate-key                 (NW2 LTS / NW3)
  sudo bash nowhere-vps.sh fingerprint nowhere://URL    (NW2 LTS / NW3)
  sudo bash nowhere-vps.sh probe [host:port]

New installs use NW3 by default. NW2 remains available at its v2.2.1 LTS baseline. Press Enter in the wizard to keep defaults.

Options:
  --client anywhere|vector|both
  --lang zh|en                    Wizard and menu language
  --skip-jq                      Do not install the optional release-list tool
  --skip-qrencode                Do not install the optional QR code tool
  --version v3.1.0 or v2.2.1 (or another listed NW3 release)
  --role portal|egress           NW3 service role
  --out direct|socks|egress      NW3 Portal target path
  --out-socks [user:pass@]host:port
  --egress-portal-host host      Portal host for an NW3 Egress service
  --egress-portal-carrier udp|udp4|udp6|tcp|tcp4|tcp6 (TLS requires v3.3.0+)
  --egress-portal-port 2077
  --cipher chacha|aes            Morph cipher for v3.4.0+ (default: chacha)
  --egress-portal-udp-carrier udp|udp4|udp6
  --egress-portal-udp-port 2077
  --egress-sni name|none --egress-pin sha256|none
  --allow-protocol-breaking-upgrade  Confirm NW2/NW3 cutover after coordinating peers
  --allow-prelude-breaking-upgrade   Confirm Morph TCP clients support authenticated preludes
  --key secret
  --public-host host              Client-facing domain or IP
  --anywhere-sni name|none        NW2 SNI for Anywhere links
  --listen-host host              Portal bind host; empty binds wildcard addresses
  --tcp-carrier tcp|tcp4|tcp6|none
  --tcp-port 2077
  --udp-carrier udp|udp4|udp6|none
  --udp-port 2077
  --tls 1|2                       1=self-signed, 2=PEM certificate
  --crt /absolute/certificate.pem --tls-key /absolute/private.key
  --morph 0|1
  --morph-tcp-prelude fade|low7|full8  fade requires NW3 v3.0.1+; existing settings are kept
  --rate 0 --etar 0 --dial auto|IP --log info
  --dial4 auto|IPv4 --dial6 auto|IPv6 (exclusive with --dial)
  --socks none|[user:pass@]host:port (NW2 Portal SOCKS5 upstream)
  --next key@host:port (NW2 native Portal upstream; exclusive with --socks)
  --next-up tcp|udp|mix --next-down tcp|udp|mix --next-mux 0|1 (NW2)
  --next-sni name|none --next-pin sha256|none (NW2)
  --vector-up tcp|udp|mix --vector-down tcp|udp|mix --mux 0|1 (NW2)
  --vector-socks 127.0.0.1:1080 --vector-rate 0 --vector-etar 0
  --sni name|none --pin sha256|none (Vector)
  --transport-memory-profile memory|balanced|throughput
  --mix-fallback-timeout 1s
  --telemetry-interval 1s
  --target host:port              Probe target; only valid with the probe command

EOF
}

require_root() { [[ "$(id -u)" -eq 0 ]] || die "Please run as root: sudo bash $0 ${ACTION}"; }
require_service_manager() {
  if [[ "$SERVICE_BACKEND" == openrc ]]; then
    command -v rc-service >/dev/null && command -v rc-update >/dev/null &&
      command -v supervise-daemon >/dev/null || die "OpenRC is required. Use an Alpine VPS or LXC booted with OpenRC."
    [[ -f /run/openrc/softlevel ]] || die "OpenRC is not running. Boot the Alpine VPS or LXC with OpenRC first."
    return
  fi
  command -v systemctl >/dev/null 2>&1 || die "systemctl is required."
  [[ -d /run/systemd/system ]] || warn "systemd does not appear to be running; service commands may fail."
}
load_config() {
  [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || true
  NOWHERE_SERVICE_URL="${NOWHERE_SERVICE_URL:-${NOWHERE_PORTAL:-}}"
  NOWHERE_ROLE_VALUE="${NOWHERE_ROLE_VALUE:-portal}"
}
validate_language() { [[ "$1" == zh || "$1" == en ]]; }
default_language() {
  case "${LC_ALL:-${LANG:-}}" in zh_*|zh.*) printf zh ;; *) printf en ;; esac
}
is_chinese() { [[ "${NOWHERE_LANG:-${NOWHERE_LANG_VALUE:-en}}" == zh ]]; }
resolve_language() {
  if [[ -n "${NOWHERE_LANG:-}" ]]; then validate_language "$NOWHERE_LANG" || die "NOWHERE_LANG must be zh or en."; return; fi
  if [[ -n "${NOWHERE_LANG_VALUE:-}" ]]; then NOWHERE_LANG="$NOWHERE_LANG_VALUE"; validate_language "$NOWHERE_LANG" || die "Saved language must be zh or en."; return; fi
  if [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then NOWHERE_LANG="$(default_language)"; return; fi
  local choice
  echo
  echo "Language / 语言："
  echo "  1) English"
  echo "  2) 简体中文"
  while true; do
    read -r -p "Choose / 请选择 [1]: " choice
    case "${choice:-1}" in 1) NOWHERE_LANG=en; return ;; 2) NOWHERE_LANG=zh; return ;; *) warn "Enter 1 or 2 / 请输入 1 或 2。" ;; esac
  done
}
prompt_value() {
  local english="$1" chinese="$2" default="$3"
  if is_chinese; then read_value "$chinese" "$default"; else read_value "$english" "$default"; fi
}

env_quote() {
  local value="${1//$'\n'/}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//\`/\\\`}"
  printf '"%s"' "$value"
}
urlencode() {
  local LC_ALL=C input="${1:-}" i byte code
  for ((i = 0; i < ${#input}; i++)); do
    byte="${input:i:1}"
    case "$byte" in
      [a-zA-Z0-9._~-]) printf '%s' "$byte" ;;
      *) printf -v code '%d' "'$byte"; printf '%%%02X' "$((code & 255))" ;;
    esac
  done
}
format_host_for_url() {
  local host="${1:-}"
  [[ -z "$host" ]] && return
  [[ "$host" == \[*\] ]] && { printf '%s' "$host"; return; }
  [[ "$host" == *:* ]] && { printf '[%s]' "$host"; return; }
  printf '%s' "$host"
}
strip_brackets() { local host="${1:-}"; host="${host#[}"; printf '%s' "${host%]}"; }
random_token() { od -An -v -N16 -tx1 /dev/urandom | tr -d '[:space:]'; }
detect_public_host() {
  local host=""
  command -v curl >/dev/null 2>&1 && host="$(curl -4fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
  [[ -n "$host" ]] || host="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  printf '%s' "$host"
}
read_value() {
  local prompt="$1" default="$2" value
  [[ "$ASSUME_YES" -eq 0 ]] || { printf '%s' "$default"; return; }
  if [[ -n "$default" ]]; then read -r -p "${prompt} [${default}]: " value; else read -r -p "${prompt}: " value; fi
  printf '%s' "${value:-$default}"
}
confirm_default_yes() {
  local answer
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  [[ -t 0 ]] || return 1
  read -r -p "$1 [Y/n]: " answer || return 1
  [[ -z "$answer" || "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

validate_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 )); }
validate_nonnegative_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
validate_carrier() {
  case "$1" in tcp|tcp4|tcp6|udp|udp4|udp6|none) return 0 ;; *) return 1 ;; esac
}
validate_tcp_carrier() { [[ "$1" == tcp || "$1" == tcp4 || "$1" == tcp6 || "$1" == none ]]; }
validate_udp_carrier() { [[ "$1" == udp || "$1" == udp4 || "$1" == udp6 || "$1" == none ]]; }
validate_policy() { [[ "$1" == tcp || "$1" == udp || "$1" == mix ]]; }
validate_bool() { [[ "$1" == 0 || "$1" == 1 ]]; }
validate_profile() { [[ "$1" == memory || "$1" == balanced || "$1" == throughput ]]; }
validate_duration() { [[ "$1" =~ ^[0-9]+(ms|s|m|h)$ ]]; }
validate_pin() { [[ "$1" == none || "$1" =~ ^[0-9a-f]{64}$ ]]; }
validate_sni() { [[ "$1" == none || "$1" =~ ^[A-Za-z0-9.-]+$ ]]; }
validate_ipv4_literal() {
  local value="$1" octet
  local -a octets
  [[ "$value" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  IFS=. read -r -a octets <<<"$value"
  for octet in "${octets[@]}"; do (( 10#$octet <= 255 )) || return 1; done
}
normalize_ipv6_embedded_ipv4() {
  local value="$1" ipv4 prefix high low
  local -a octets
  [[ "$value" == *.* ]] || { printf '%s' "$value"; return; }
  [[ "$value" == *:* ]] || return 1
  ipv4="${value##*:}"; prefix="${value%:*}"
  validate_ipv4_literal "$ipv4" || return 1
  IFS=. read -r -a octets <<<"$ipv4"
  high=$((10#${octets[0]} * 256 + 10#${octets[1]}))
  low=$((10#${octets[2]} * 256 + 10#${octets[3]}))
  printf '%s:%x:%x' "$prefix" "$high" "$low"
}
validate_ipv6_literal() {
  local value="$1" left right side group count=0
  local -a groups
  value="$(normalize_ipv6_embedded_ipv4 "$value")" || return 1
  [[ "$value" == *:* && "$value" != *%* && "$value" != *[!A-Fa-f0-9:]* && "$value" != *:::* ]] || return 1
  if [[ "$value" == *::* ]]; then
    left="${value%%::*}"; right="${value#*::}"
    [[ "$right" != *::* ]] || return 1
    for side in "$left" "$right"; do
      [[ -z "$side" ]] && continue
      [[ "$side" != :* && "$side" != *: ]] || return 1
      IFS=: read -r -a groups <<<"$side"
      for group in "${groups[@]}"; do [[ "$group" =~ ^[A-Fa-f0-9]{1,4}$ ]] || return 1; ((count+=1)); done
    done
    (( count < 8 ))
  else
    [[ "$value" != :* && "$value" != *: ]] || return 1
    IFS=: read -r -a groups <<<"$value"
    (( ${#groups[@]} == 8 )) || return 1
    for group in "${groups[@]}"; do [[ "$group" =~ ^[A-Fa-f0-9]{1,4}$ ]] || return 1; done
  fi
}
is_ipv4_mapped_ipv6() {
  local value left right index right_count=0 fill_count
  local -a groups=() expanded=()
  value="$(normalize_ipv6_embedded_ipv4 "$1")" || return 1
  value="$(printf '%s' "$value" | tr 'A-F' 'a-f')"
  if [[ "$value" == *::* ]]; then
    left="${value%%::*}"; right="${value#*::}"
    [[ -z "$left" ]] || { IFS=: read -r -a groups <<<"$left"; expanded+=("${groups[@]}"); }
    if [[ -n "$right" ]]; then IFS=: read -r -a groups <<<"$right"; right_count=${#groups[@]}; fi
    fill_count=$((8 - ${#expanded[@]} - right_count))
    for ((index=0; index<fill_count; index++)); do expanded+=(0); done
    [[ -z "$right" ]] || expanded+=("${groups[@]}")
  else
    IFS=: read -r -a expanded <<<"$value"
  fi
  (( ${#expanded[@]} == 8 )) && [[ "${expanded[0]}${expanded[1]}${expanded[2]}${expanded[3]}${expanded[4]}" =~ ^0+$ ]] && [[ "${expanded[5]}" == ffff ]]
}
validate_ip_family() {
  case "$1" in
    4) validate_ipv4_literal "$2" ;;
    6) validate_ipv6_literal "$2" ;;
    *) return 1 ;;
  esac
}
validate_shared_key() { [[ "$1" =~ ^[0-9a-f]{32,64}$ ]]; }
validate_nw3_key() { [[ "$1" =~ ^[0-9a-f]{32}$ ]]; }
validate_key_for_version() {
  if is_nw3_version "$1"; then validate_nw3_key "$2"; else validate_shared_key "$2"; fi
}
validate_socks() {
  local value="$1" endpoint host port credentials username password
  [[ "$value" == none || -z "$value" ]] && return 0
  [[ "$value" != *[[:space:]]* ]] || return 1
  if [[ "$value" == *@* ]]; then
    credentials="${value%@*}"
    [[ "$credentials" == *:* ]] || return 1
    username="${credentials%%:*}"; password="${credentials#*:}"
    [[ -n "$username" && -n "$password" ]] || return 1
  fi
  endpoint="${value##*@}"
  if [[ "$endpoint" == \[*\]:* ]]; then host="${endpoint#\[}"; host="${host%%\]:*}"; port="${endpoint##*\]:}"; else host="${endpoint%:*}"; port="${endpoint##*:}"; fi
  [[ -n "$host" ]] && validate_port "$port"
}
encode_socks_query_value() {
  local value="$1" credentials endpoint username password
  if [[ "$value" != *@* ]]; then urlencode "$value"; return; fi
  credentials="${value%@*}"; endpoint="${value##*@}"
  username="${credentials%%:*}"; password="${credentials#*:}"
  printf '%s:%s@%s' "$(urlencode "$username")" "$(urlencode "$password")" "$(urlencode "$endpoint")"
}
validate_vector_socks() { [[ "$1" != none && -n "$1" ]] && validate_socks "$1"; }
carrier_for_policy() {
  case "$1" in
    tcp) [[ "$NOWHERE_TCP_CARRIER" != none ]] ;;
    udp) [[ "$NOWHERE_UDP_CARRIER" != none ]] ;;
    *) return 1 ;;
  esac
}
validate_policy_for_endpoint() {
  local up="$1" down="$2"
  validate_policy "$up" && validate_policy "$down" || return 1
  [[ "$up" != mix && "$down" != mix ]] || [[ "$NOWHERE_TCP_CARRIER" != none && "$NOWHERE_UDP_CARRIER" != none ]] || return 1
  [[ "$up" == mix ]] || carrier_for_policy "$up" || return 1
  [[ "$down" == mix ]] || carrier_for_policy "$down" || return 1
}
validate_dial_settings() {
  local dial4="${NOWHERE_DIAL4:-auto}" dial6="${NOWHERE_DIAL6:-auto}"
  if [[ "$NOWHERE_DIAL" != auto ]]; then
    if validate_ipv4_literal "$NOWHERE_DIAL"; then :
    elif validate_ipv6_literal "$NOWHERE_DIAL"; then :
    else return 1; fi
  fi
  if [[ "$dial4" != auto || "$dial6" != auto ]]; then
    [[ "$NOWHERE_DIAL" == auto && "$DIAL_EXPLICIT" -eq 0 ]] || return 1
    [[ "$dial4" == auto ]] || validate_ip_family 4 "$dial4" || return 1
    [[ "$dial6" == auto ]] || { validate_ipv6_literal "$dial6" && ! is_ipv4_mapped_ipv6 "$dial6"; } || return 1
  fi
}
normalize_client() { case "$1" in anywhere|vector|both) printf '%s' "$1" ;; *) return 1 ;; esac; }
client_label() { case "$1" in anywhere) printf 'Anywhere' ;; vector) printf 'Native Vector' ;; both) printf 'Anywhere + Native Vector' ;; esac; }

validate_release_version() {
  local major
  [[ "$1" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || return 1
  major="${BASH_REMATCH[1]}"
  if [[ "$major" == 2 ]]; then [[ "$1" == "$NW2_LTS_VERSION" ]]; return; fi
  [[ "$major" == 3 ]]
}
validate_installed_version() {
  local major
  [[ "$1" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || return 1
  major="${BASH_REMATCH[1]}"
  [[ "$major" == 2 || "$major" == 3 ]]
}
require_supported_version() { validate_release_version "$1" || die "Supported Nowhere releases are v${NW2_LTS_VERSION#v} (NW2 LTS) and NW3 releases with vMAJOR.MINOR.PATCH tags."; }
require_supported_installed_version() { validate_installed_version "$1" || die "Only stable NW2 and NW3 installations are recognized."; }
is_nw3_version() { [[ "$1" =~ ^v3\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; }
require_deployable_version() {
  require_supported_version "$1"
  return 0
}
version_at_least() {
  local version="${1#v}" minimum="${2#v}" major minor patch min_major min_minor min_patch
  IFS=. read -r major minor patch <<<"$version"
  IFS=. read -r min_major min_minor min_patch <<<"$minimum"
  (( major > min_major || (major == min_major && minor > min_minor) ||
    (major == min_major && minor == min_minor && patch >= min_patch) ))
}
default_morph_tcp_prelude() {
  if is_nw3_version "$1" && version_at_least "$1" v3.0.1; then printf fade; else printf '%s' "$DEFAULT_MORPH_TCP_PRELUDE"; fi
}
validate_morph_tcp_prelude() {
  [[ "$1" == low7 || "$1" == full8 ]] && return 0
  [[ "$1" == fade ]] && is_nw3_version "$NOWHERE_VERSION" && version_at_least "$NOWHERE_VERSION" v3.0.1
}
confirm_prelude_upgrade() {
  local current="$1" selected="$2" answer
  is_nw3_version "$selected" && version_at_least "$selected" v3.2.0 || return 0
  if is_nw3_version "$current" && version_at_least "$current" v3.2.0; then return 0; fi
  [[ "${NOWHERE_ROLE:-${NOWHERE_ROLE_VALUE:-portal}}" == portal &&
    "${NOWHERE_MORPH:-${NOWHERE_MORPH_VALUE:-1}}" == 1 &&
    "${NOWHERE_TCP_CARRIER:-${NOWHERE_TCP_CARRIER_VALUE:-tcp}}" != none ]] || return 0
  if is_chinese; then
    warn "目标版本要求 Morph TCP 客户端支持认证前导。原生 Vector 需要 3.1.0+；请确认 Anywhere 已支持。"
  else
    warn "Morph TCP now requires authenticated preludes. Native Vector needs 3.1.0+; verify Anywhere support before upgrading."
  fi
  [[ "$ALLOW_PRELUDE_BREAKING_UPGRADE" -eq 0 ]] || return 0
  [[ "$ASSUME_YES" -eq 0 && -t 0 ]] || die "Confirm compatible Morph TCP clients with --allow-prelude-breaking-upgrade."
  if is_chinese; then read -r -p "确认客户端兼容后，输入 UPGRADE 继续: " answer
  else read -r -p "After checking client compatibility, type UPGRADE: " answer; fi
  [[ "$answer" == UPGRADE ]] || { warn "Update cancelled."; return 1; }
}
require_supported_nowhere() {
  local installed
  require_root
  [[ -x "$BIN_PATH" ]] || die "Nowhere is not installed."
  load_config
  installed="${NOWHERE_VERSION_VALUE:-}"
  [[ -n "$installed" ]] || die "No installation config found."
  require_supported_installed_version "$installed"
}
validate_log_level() {
  [[ "$1" =~ ^(none|debug|info|warn|error)$ ]]
}
confirm_protocol_upgrade() {
  local current="$1" selected="$2" answer current_profile target_profile
  if is_nw3_version "$current"; then current_profile=nw3; else current_profile=nw2; fi
  if is_nw3_version "$selected"; then target_profile=nw3; else target_profile=nw2; fi
  [[ "$current_profile" == "$target_profile" ]] && return 0
  warn "NW2 and NW3 use incompatible wire protocols; all peers on the traffic path must be switched together."
  warn "This operation rebuilds the service URL and client links for the selected protocol generation."
  if [[ "$ALLOW_PROTOCOL_BREAKING_UPGRADE" -eq 1 ]]; then
    warn "Proceeding because --allow-protocol-breaking-upgrade was supplied."
    return 0
  fi
  [[ "$ASSUME_YES" -eq 0 && -t 0 ]] || die "Refusing non-interactive NW2/NW3 migration. Coordinate every peer, then add --allow-protocol-breaking-upgrade."
  read -r -p "Type MIGRATE to continue: " answer
  [[ "$answer" == MIGRATE ]] || { warn "Update cancelled."; return 1; }
}
KEY_MIGRATED=0
migrate_shared_key_for_version() {
  local version="$1" next_key portal_tail can_rotate=0
  KEY_MIGRATED=0
  require_supported_version "$version"
  if [[ "${NOWHERE_NEXT:-none}" != none ]]; then
    if is_nw3_version "$version"; then
      if is_chinese; then warn "NW3 已移除原生 next 参数；请在向导中改用 direct、SOCKS5 或 Egress 出口。"; else warn "NW3 removes native next; choose direct, SOCKS5, or Egress in the wizard."; fi
      return 1
    fi
    next_key="${NOWHERE_NEXT%%@*}"
    if ! validate_key_for_version "$version" "$next_key"; then
      if is_chinese; then
        warn "目标版本要求 next 密钥为 32–64 位小写十六进制。请先在上游 Portal 与此处配置相同的新密钥，再重新更新。"
      else
        warn "The target release requires a compatible lowercase hexadecimal next key. Set the same key on the upstream Portal and here, then retry."
      fi
      return 1
    fi
  fi
  validate_key_for_version "$version" "${NOWHERE_KEY:-}" && return 0
  if [[ "${KEY_MIGRATION_FORCE:-0}" == 1 ]]; then
    can_rotate=1
  elif [[ -n "${NOWHERE_KEY_VALUE:-}" && "$NOWHERE_KEY" == "$NOWHERE_KEY_VALUE" ]]; then
    if [[ "$version" == "$NW2_LTS_VERSION" && "${NOWHERE_VERSION_VALUE:-$NW2_LTS_VERSION}" != "$NW2_LTS_VERSION" ]] ||
      { is_nw3_version "$version" && ! is_nw3_version "${NOWHERE_VERSION_VALUE:-$NW2_LTS_VERSION}"; }; then
      can_rotate=1
    fi
  fi
  if [[ "$can_rotate" -ne 1 ]]; then
    if is_chinese; then warn "当前共享密钥格式不兼容，且无法安全自动迁移。请先通过“修改配置”设置新密钥，再更新。"; else warn "The saved Portal key is incompatible and cannot be migrated automatically. Set a new key through Reconfigure, then retry the update."; fi
    return 1
  fi
  if is_chinese; then
    warn "目标版本不接受当前 Portal 密钥格式；轮换后旧客户端链接将失效，需要重新导入。"
    confirm_default_yes "生成新密钥并继续迁移？" || { warn "迁移已取消。"; return 1; }
  else
    warn "The target release rejects the current Portal key format. Rotating it invalidates existing client links; clients must import the new link."
    confirm_default_yes "Generate a new key and continue the migration?" || { warn "Migration cancelled."; return 1; }
  fi
  NOWHERE_KEY="$(random_token)"
  NOWHERE_KEY_VALUE="$NOWHERE_KEY"
  if [[ "${NOWHERE_PORTAL:-}" == portal://*@* ]]; then
    portal_tail="${NOWHERE_PORTAL#*@}"
    NOWHERE_PORTAL="portal://${NOWHERE_KEY}@${portal_tail}"
    NOWHERE_SERVICE_URL="$NOWHERE_PORTAL"
  fi
  KEY_MIGRATED=1
}
persist_shared_key_migration() {
  [[ "$KEY_MIGRATED" -eq 1 ]] || return 0
  write_config_assignment NOWHERE_PORTAL "$NOWHERE_PORTAL"
  write_config_assignment NOWHERE_SERVICE_URL "${NOWHERE_SERVICE_URL:-$NOWHERE_PORTAL}"
  write_config_assignment NOWHERE_KEY_VALUE "$NOWHERE_KEY"
}
REMOVED_EVENT_LOG_MIGRATED=0
normalize_removed_event_logs() {
  REMOVED_EVENT_LOG_MIGRATED=0
  if [[ "${NOWHERE_LOG_VALUE:-${NOWHERE_LOG:-}}" == event || "${NOWHERE_LOG:-}" == event ]]; then
    NOWHERE_LOG_VALUE=info; NOWHERE_LOG=info; REMOVED_EVENT_LOG_MIGRATED=1
  fi
  if [[ "${NOWHERE_VECTOR_LOG_VALUE:-${NOWHERE_VECTOR_LOG:-}}" == event || "${NOWHERE_VECTOR_LOG:-}" == event ]]; then
    NOWHERE_VECTOR_LOG_VALUE=info; NOWHERE_VECTOR_LOG=info; REMOVED_EVENT_LOG_MIGRATED=1
  fi
  if [[ "${NOWHERE_PORTAL:-}" == *log=event* ]]; then
    NOWHERE_PORTAL="${NOWHERE_PORTAL//log=event/log=info}"
    NOWHERE_SERVICE_URL="$NOWHERE_PORTAL"
    REMOVED_EVENT_LOG_MIGRATED=1
  fi
  if [[ "$REMOVED_EVENT_LOG_MIGRATED" -eq 1 ]]; then
    if is_chinese; then warn "当前受支持版本不再使用 event 日志级别，旧设置已自动改为 info。"; else warn "Supported releases do not use the event log level; legacy settings were changed to info."; fi
  fi
}
escape_sed_replacement() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//&/\\&}"
  value="${value//|/\\|}"
  printf '%s' "$value"
}
write_config_assignment() {
  local name="$1" value="$2" quoted replacement
  quoted="$(env_quote "$value")"
  replacement="$(escape_sed_replacement "$quoted")"
  if grep -q "^${name}=" "$CONFIG_FILE"; then
    sed -i.bak "s|^${name}=.*|${name}=${replacement}|" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
  else
    printf '\n%s=%s\n' "$name" "$quoted" >>"$CONFIG_FILE"
  fi
}
persist_removed_event_log_migration() {
  [[ "$REMOVED_EVENT_LOG_MIGRATED" -eq 1 ]] || return 0
  write_config_assignment NOWHERE_PORTAL "${NOWHERE_PORTAL:-}"
  write_config_assignment NOWHERE_SERVICE_URL "${NOWHERE_SERVICE_URL:-${NOWHERE_PORTAL:-}}"
  write_config_assignment NOWHERE_LOG_VALUE "$NOWHERE_LOG_VALUE"
  write_config_assignment NOWHERE_VECTOR_LOG_VALUE "$NOWHERE_VECTOR_LOG_VALUE"
}
validate_config() {
  require_deployable_version "$NOWHERE_VERSION"
  NOWHERE_CLIENT="$(normalize_client "$NOWHERE_CLIENT")" || die "NOWHERE_CLIENT must be anywhere, vector, or both."
  [[ -n "$NOWHERE_KEY" && "${#NOWHERE_KEY}" -le 255 ]] || die "NOWHERE_KEY must contain 1..255 characters."
  validate_shared_key "$NOWHERE_KEY" || die "The NW2 LTS requires a 32–64-character lowercase hexadecimal Portal key."
  validate_tcp_carrier "$NOWHERE_TCP_CARRIER" || die "NOWHERE_TCP_CARRIER must be tcp, tcp4, tcp6, or none."
  validate_udp_carrier "$NOWHERE_UDP_CARRIER" || die "NOWHERE_UDP_CARRIER must be udp, udp4, udp6, or none."
  [[ "$NOWHERE_TCP_CARRIER" != none || "$NOWHERE_UDP_CARRIER" != none ]] || die "Enable at least one carrier."
  [[ "$NOWHERE_TCP_CARRIER" == none ]] || validate_port "$NOWHERE_TCP_PORT" || die "Invalid TCP port."
  [[ "$NOWHERE_UDP_CARRIER" == none ]] || validate_port "$NOWHERE_UDP_PORT" || die "Invalid UDP port."
  [[ "$NOWHERE_TLS" == 1 || "$NOWHERE_TLS" == 2 ]] || die "NOWHERE_TLS must be 1 or 2."
  validate_bool "$NOWHERE_MORPH" || die "NOWHERE_MORPH must be 0 or 1."
  validate_language "$NOWHERE_LANG" || die "NOWHERE_LANG must be zh or en."
  validate_sni "$NOWHERE_ANYWHERE_SNI" || die "NOWHERE_ANYWHERE_SNI must be a DNS name or none."
  validate_morph_tcp_prelude "$NOWHERE_MORPH_TCP_PRELUDE" || die "NOWHERE_MORPH_TCP_PRELUDE must be low7 or full8."
  validate_nonnegative_int "$NOWHERE_RATE" && validate_nonnegative_int "$NOWHERE_ETAR" || die "Rate limits must be non-negative integers."
  validate_socks "$NOWHERE_SOCKS" || die "Invalid NOWHERE_SOCKS value."
  validate_dial_settings || die "Invalid outbound dial settings. Use one --dial IP or the mutually exclusive --dial4/--dial6 options."
  validate_log_level "$NOWHERE_LOG" || die "Invalid log level for Nowhere ${NOWHERE_VERSION}."
  validate_profile "$NOWHERE_TRANSPORT_MEMORY_PROFILE" || die "Invalid transport memory profile."
  validate_duration "$NOWHERE_MIX_FALLBACK_TIMEOUT" || die "Invalid mix fallback timeout."
  validate_duration "$NOWHERE_TELEMETRY_INTERVAL" || die "Invalid telemetry interval."
  if [[ "$NOWHERE_TLS" == 2 ]]; then
    [[ -n "$NOWHERE_CRT" && -n "$NOWHERE_TLS_KEY" ]] || die "tls=2 requires crt and key paths."
    [[ -f "$NOWHERE_CRT" && -f "$NOWHERE_TLS_KEY" ]] || die "Certificate or private-key file does not exist."
  fi
  if [[ "$NOWHERE_NEXT" != none ]]; then
    [[ "$NOWHERE_SOCKS" == none ]] || die "Portal next and SOCKS outbound paths are mutually exclusive."
    [[ "$NOWHERE_NEXT" == *@* ]] || die "NOWHERE_NEXT must be key@host:port or an explicit carrier endpoint."
    validate_shared_key "${NOWHERE_NEXT%%@*}" || die "The NW2 LTS requires a 32–64-character lowercase hexadecimal next key."
    validate_policy_for_endpoint "$NOWHERE_NEXT_UP" "$NOWHERE_NEXT_DOWN" || die "Invalid next route policy for enabled carriers."
    validate_bool "$NOWHERE_NEXT_MUX" && validate_sni "$NOWHERE_NEXT_SNI" && validate_pin "$NOWHERE_NEXT_PIN" || die "Invalid next Mux, SNI, or pin."
  fi
  if [[ "$NOWHERE_CLIENT" == vector || "$NOWHERE_CLIENT" == both ]]; then
    validate_policy_for_endpoint "$NOWHERE_VECTOR_UP" "$NOWHERE_VECTOR_DOWN" || die "Invalid Vector route policy for enabled carriers."
    validate_bool "$NOWHERE_VECTOR_MUX" && validate_sni "$NOWHERE_VECTOR_SNI" && validate_pin "$NOWHERE_VECTOR_PIN" || die "Invalid Vector Mux, SNI, or pin."
    validate_vector_socks "$NOWHERE_VECTOR_SOCKS" || die "Invalid Vector SOCKS listener."
    validate_nonnegative_int "$NOWHERE_VECTOR_RATE" && validate_nonnegative_int "$NOWHERE_VECTOR_ETAR" || die "Vector rate limits must be non-negative integers."
    validate_log_level "$NOWHERE_VECTOR_LOG" || die "Invalid Vector log level for Nowhere ${NOWHERE_VERSION}."
  fi
}

build_endpoint() {
  local host="$1" tcp_carrier="$2" tcp_port="$3" udp_carrier="$4" udp_port="$5"
  if [[ "$tcp_carrier" != none && "$udp_carrier" != none && "$tcp_carrier" == tcp && "$udp_carrier" == udp && "$tcp_port" == "$udp_port" ]]; then
    printf '%s:%s' "$host" "$tcp_port"
  elif [[ "$tcp_carrier" != none && "$udp_carrier" != none ]]; then
    printf '%s/%s:%s/%s:%s' "$host" "$tcp_carrier" "$tcp_port" "$udp_carrier" "$udp_port"
  elif [[ "$tcp_carrier" != none ]]; then
    printf '%s/%s:%s' "$host" "$tcp_carrier" "$tcp_port"
  else
    printf '%s/%s:%s' "$host" "$udp_carrier" "$udp_port"
  fi
}
carrier_without_family() {
  case "$1" in tcp4|tcp6) printf tcp ;; udp4|udp6) printf udp ;; *) printf '%s' "$1" ;; esac
}
supports_tls_egress() { is_nw3_version "$1" && version_at_least "$1" "$TLS_EGRESS_MIN_VERSION"; }
supports_morph_cipher() { is_nw3_version "$1" && version_at_least "$1" "$CIPHER_MIN_VERSION"; }
nw3_morph_query() {
  printf 'morph=%s' "$2"
  if [[ "$2" == 1 && "$3" == aes ]] && supports_morph_cipher "$1"; then printf '&cipher=aes'; fi
}
prompt_morph_cipher() {
  if [[ "$NOWHERE_MORPH" == 1 ]] && supports_morph_cipher "$NOWHERE_VERSION"; then
    NOWHERE_CIPHER="$(prompt_value "Morph cipher chacha/aes (must match peers)" "Morph 算法 chacha/aes（须与对端一致）" "$NOWHERE_CIPHER")"
  fi
}
egress_transport_label() {
  case "$1" in tcp|tcp4|tcp6) printf 'TLS/TCP' ;; *) printf 'QUIC/UDP' ;; esac
}
build_portal_url() {
  local key host query endpoint
  key="$(urlencode "$NOWHERE_KEY")"
  host="$(format_host_for_url "$NOWHERE_LISTEN_HOST")"
  [[ -n "$host" ]] || host="*"
  endpoint="$(build_endpoint "$host" "$NOWHERE_TCP_CARRIER" "$NOWHERE_TCP_PORT" "$NOWHERE_UDP_CARRIER" "$NOWHERE_UDP_PORT")"
  query="tls=${NOWHERE_TLS}&morph=${NOWHERE_MORPH}"
  [[ "$NOWHERE_RATE" == 0 ]] || query="${query}&rate=${NOWHERE_RATE}"
  [[ "$NOWHERE_ETAR" == 0 ]] || query="${query}&etar=${NOWHERE_ETAR}"
  if [[ "$NOWHERE_DIAL" != auto ]]; then
    query="${query}&dial=$(urlencode "$NOWHERE_DIAL")"
  else
    [[ "${NOWHERE_DIAL4:-auto}" == auto ]] || query="${query}&dial4=$(urlencode "$NOWHERE_DIAL4")"
    [[ "${NOWHERE_DIAL6:-auto}" == auto ]] || query="${query}&dial6=$(urlencode "$NOWHERE_DIAL6")"
  fi
  [[ "$NOWHERE_SOCKS" == none ]] || query="${query}&socks=$(urlencode "$NOWHERE_SOCKS")"
  if [[ "$NOWHERE_NEXT" != none ]]; then
    query="${query}&next=$(urlencode "$NOWHERE_NEXT")&up=${NOWHERE_NEXT_UP}&down=${NOWHERE_NEXT_DOWN}&mux=${NOWHERE_NEXT_MUX}"
    query="${query}&sni=$(urlencode "$NOWHERE_NEXT_SNI")&pin=$(urlencode "$NOWHERE_NEXT_PIN")"
  fi
  [[ "$NOWHERE_TLS" != 2 ]] || query="${query}&crt=$(urlencode "$NOWHERE_CRT")&key=$(urlencode "$NOWHERE_TLS_KEY")"
  [[ "$NOWHERE_LOG" == "$DEFAULT_LOG" ]] || query="${query}&log=${NOWHERE_LOG}"
  printf 'portal://%s@%s?%s' "$key" "$endpoint" "$query"
}
build_vector_query() {
  local include_socks="${1:-1}"
  local up="${NOWHERE_VECTOR_UP_VALUE:-${NOWHERE_VECTOR_UP:-tcp}}" down="${NOWHERE_VECTOR_DOWN_VALUE:-${NOWHERE_VECTOR_DOWN:-tcp}}" mux="${NOWHERE_VECTOR_MUX_VALUE:-${NOWHERE_VECTOR_MUX:-$DEFAULT_MUX}}"
  local sni="${NOWHERE_VECTOR_SNI_VALUE:-${NOWHERE_VECTOR_SNI:-$DEFAULT_SNI}}" pin="${NOWHERE_VECTOR_PIN_VALUE:-${NOWHERE_VECTOR_PIN:-$DEFAULT_PIN}}" morph="${NOWHERE_MORPH_VALUE:-${NOWHERE_MORPH:-$DEFAULT_MORPH}}"
  local socks="${NOWHERE_VECTOR_SOCKS_VALUE:-${NOWHERE_VECTOR_SOCKS:-$DEFAULT_VECTOR_SOCKS}}" rate="${NOWHERE_VECTOR_RATE_VALUE:-${NOWHERE_VECTOR_RATE:-0}}" etar="${NOWHERE_VECTOR_ETAR_VALUE:-${NOWHERE_VECTOR_ETAR:-0}}" log="${NOWHERE_VECTOR_LOG_VALUE:-${NOWHERE_VECTOR_LOG:-$DEFAULT_LOG}}"
  local version="${NOWHERE_VERSION_VALUE:-${NOWHERE_VERSION:-$DEFAULT_VERSION}}" tls="${NOWHERE_TLS_VALUE:-${NOWHERE_TLS:-$DEFAULT_TLS}}" fingerprint query
  if is_nw3_version "$version"; then
    if [[ "$tls" == 1 && "$pin" == none ]]; then
      fingerprint="$(current_local_tls_fingerprint || true)"
      [[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]] || { warn "Cannot create a verified NW3 self-signed client URL: certificate fingerprint is unavailable. Check the Nowhere service logs."; return 1; }
      pin="$fingerprint"
    fi
    query="$(nw3_morph_query "$version" "$morph" "${NOWHERE_CIPHER_VALUE:-chacha}")"
    [[ "$include_socks" != 1 ]] || query="in=$(encode_socks_query_value "$socks")&${query}"
    [[ "$sni" == none ]] || query="${query}&sni=$(urlencode "$sni")"
    [[ "$pin" == none ]] || query="${query}&pin=${pin}"
    [[ "$rate" == 0 ]] || query="${query}&rate=${rate}"
    [[ "$etar" == 0 ]] || query="${query}&etar=${etar}"
    printf '%s' "$query"
    return
  fi
  if [[ "$tls" == 1 && "$pin" == none ]]; then
    fingerprint="$(current_local_tls_fingerprint || true)"
    [[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]] || { warn "Cannot create a verified self-signed client URL: certificate fingerprint is unavailable. Check the Nowhere service logs."; return 1; }
    pin="$fingerprint"
  fi
  local query="up=${up}&down=${down}&mux=${mux}"
  query="${query}&sni=$(urlencode "$sni")&pin=$(urlencode "$pin")"
  query="${query}&morph=${morph}"
  if [[ "$include_socks" == 1 ]]; then query="${query}&socks=$(urlencode "$socks")"; fi
  [[ "$rate" == 0 ]] || query="${query}&rate=${rate}"
  [[ "$etar" == 0 ]] || query="${query}&etar=${etar}"
  [[ "$log" == "$DEFAULT_LOG" ]] || query="${query}&log=${log}"
  printf '%s' "$query"
}
validate_probe_target() {
  local target="$1" host port
  [[ -n "$target" && "$target" != *[[:space:]]* ]] || return 1
  if [[ "$target" == \[*\]:* ]]; then
    host="${target#\[}"; host="${host%%\]:*}"; port="${target##*\]:}"
  else
    [[ "$target" == *:* ]] || return 1
    host="${target%:*}"; port="${target##*:}"
    [[ "$host" != *:* ]] || return 1
  fi
  [[ -n "$host" ]] && validate_port "$port"
}
build_probe_vector_url() {
  load_config
  [[ "${NOWHERE_ROLE_VALUE:-portal}" != egress ]] || die "TCP probe is only available from a Portal deployment."
  [[ -n "${NOWHERE_KEY_VALUE:-}" ]] || die "No configuration found."
  local public_host="${NOWHERE_PUBLIC_HOST_VALUE:-}" host key endpoint query
  [[ -n "$public_host" ]] || die "Public host is empty. Reconfigure the service."
  case "$public_host" in '*'|0.0.0.0|::|'[::]') die "A concrete public host is required for the probe." ;; esac
  [[ "${NOWHERE_TCP_CARRIER_VALUE:-none}" != none || "${NOWHERE_UDP_CARRIER_VALUE:-none}" != none ]] || die "No carrier is enabled."
  host="$(format_host_for_url "$public_host")"
  key="$(urlencode "$NOWHERE_KEY_VALUE")"
  if is_nw3_version "${NOWHERE_VERSION_VALUE:-$DEFAULT_VERSION}"; then
    if [[ "${NOWHERE_TCP_CARRIER_VALUE:-none}" != none ]]; then
      endpoint="$(build_endpoint "$host" "${NOWHERE_TCP_CARRIER_VALUE}" "${NOWHERE_TCP_PORT_VALUE:-$DEFAULT_PORT}" none "$DEFAULT_PORT")"
    else
      endpoint="$(build_endpoint "$host" none "$DEFAULT_PORT" "${NOWHERE_UDP_CARRIER_VALUE}" "${NOWHERE_UDP_PORT_VALUE:-$DEFAULT_PORT}")"
    fi
    query="$(build_vector_query 0)"
    printf 'vector://%s@%s?%s' "$key" "$endpoint" "$query"
    return
  fi
  endpoint="$(build_endpoint "$host" "${NOWHERE_TCP_CARRIER_VALUE:-none}" "${NOWHERE_TCP_PORT_VALUE:-$DEFAULT_PORT}" "${NOWHERE_UDP_CARRIER_VALUE:-none}" "${NOWHERE_UDP_PORT_VALUE:-$DEFAULT_PORT}")"

  local NOWHERE_TCP_CARRIER="${NOWHERE_TCP_CARRIER_VALUE:-none}"
  local NOWHERE_UDP_CARRIER="${NOWHERE_UDP_CARRIER_VALUE:-none}"
  local NOWHERE_VECTOR_UP_VALUE="${NOWHERE_VECTOR_UP_VALUE:-tcp}"
  local NOWHERE_VECTOR_DOWN_VALUE="${NOWHERE_VECTOR_DOWN_VALUE:-tcp}"
  if ! validate_policy_for_endpoint "$NOWHERE_VECTOR_UP_VALUE" "$NOWHERE_VECTOR_DOWN_VALUE"; then
    if [[ "${NOWHERE_CLIENT_VALUE:-anywhere}" != anywhere ]]; then die "Saved Vector route is incompatible with the enabled carriers; reconfigure the service."; fi
    if [[ "$NOWHERE_TCP_CARRIER" != none ]]; then NOWHERE_VECTOR_UP_VALUE=tcp; NOWHERE_VECTOR_DOWN_VALUE=tcp; else NOWHERE_VECTOR_UP_VALUE=udp; NOWHERE_VECTOR_DOWN_VALUE=udp; fi
    if is_chinese; then warn "当前 Vector 路由与启用的载体不匹配；本次探测临时使用 ${NOWHERE_VECTOR_UP_VALUE}/${NOWHERE_VECTOR_DOWN_VALUE}。"; else warn "Saved Vector route is unavailable; this probe will use ${NOWHERE_VECTOR_UP_VALUE}/${NOWHERE_VECTOR_DOWN_VALUE}."; fi
  fi
  query="$(build_vector_query 0)"
  printf 'vector://%s@%s?%s' "$key" "$endpoint" "$query"
}
build_anywhere_query() {
  local up="$1" down="$2"
  local sni="${NOWHERE_ANYWHERE_SNI_VALUE:-${NOWHERE_ANYWHERE_SNI:-none}}"
  local public_host="${NOWHERE_PUBLIC_HOST_VALUE:-${NOWHERE_PUBLIC_HOST:-}}"
  printf 'up=%s&down=%s&morph=%s&mux=%s' "$up" "$down" "${NOWHERE_MORPH_VALUE:-$DEFAULT_MORPH}" "${NOWHERE_VECTOR_MUX_VALUE:-$DEFAULT_MUX}"
  if [[ "$sni" != none && "$sni" != "$public_host" ]]; then printf '&sni=%s' "$(urlencode "$sni")"; fi
}

configure_values() {
  load_config
  local generated_key detected_host default_tls path
  resolve_language
  generated_key="$(random_token)"; detected_host="$(detect_public_host)"
  NOWHERE_VERSION="${NOWHERE_VERSION:-${NOWHERE_VERSION_VALUE:-$DEFAULT_VERSION}}"
  require_deployable_version "$NOWHERE_VERSION"
  if is_nw3_version "$NOWHERE_VERSION"; then configure_nw3_values "$generated_key" "$detected_host"; return; fi
  [[ "${NOWHERE_CIPHER:-chacha}" == chacha ]] || die "The selected Morph cipher requires NW3 v3.4.0+."
  NOWHERE_CIPHER=chacha
  [[ "${NOWHERE_ROLE:-${NOWHERE_ROLE_VALUE:-portal}}" != egress ]] || die "NW2 has no Egress role; choose an NW3 release or configure a Portal role."
  NOWHERE_ROLE=portal
  NOWHERE_CLIENT="${NOWHERE_CLIENT:-${NOWHERE_CLIENT_VALUE:-$DEFAULT_CLIENT}}"
  NOWHERE_PUBLIC_HOST="${NOWHERE_PUBLIC_HOST:-${NOWHERE_PUBLIC_HOST_VALUE:-$detected_host}}"
  NOWHERE_ANYWHERE_SNI="${NOWHERE_ANYWHERE_SNI:-${NOWHERE_ANYWHERE_SNI_VALUE:-none}}"
  NOWHERE_LISTEN_HOST="${NOWHERE_LISTEN_HOST:-${NOWHERE_LISTEN_HOST_VALUE:-}}"
  NOWHERE_KEY="${NOWHERE_KEY:-${NOWHERE_KEY_VALUE:-$generated_key}}"
  NOWHERE_TCP_CARRIER="${NOWHERE_TCP_CARRIER:-${NOWHERE_TCP_CARRIER_VALUE:-$DEFAULT_TCP_CARRIER}}"
  NOWHERE_TCP_PORT="${NOWHERE_TCP_PORT:-${NOWHERE_TCP_PORT_VALUE:-$DEFAULT_PORT}}"
  NOWHERE_UDP_CARRIER="${NOWHERE_UDP_CARRIER:-${NOWHERE_UDP_CARRIER_VALUE:-$DEFAULT_UDP_CARRIER}}"
  NOWHERE_UDP_PORT="${NOWHERE_UDP_PORT:-${NOWHERE_UDP_PORT_VALUE:-$DEFAULT_PORT}}"
  NOWHERE_CRT="${NOWHERE_CRT:-${NOWHERE_CRT_VALUE:-}}"; NOWHERE_TLS_KEY="${NOWHERE_TLS_KEY:-${NOWHERE_TLS_KEY_VALUE:-}}"
  default_tls="$DEFAULT_TLS"; [[ -n "$NOWHERE_CRT$NOWHERE_TLS_KEY" ]] && default_tls=2
  NOWHERE_TLS="${NOWHERE_TLS:-${NOWHERE_TLS_VALUE:-$default_tls}}"
  NOWHERE_MORPH="${NOWHERE_MORPH:-${NOWHERE_MORPH_VALUE:-$DEFAULT_MORPH}}"
  NOWHERE_MORPH_TCP_PRELUDE="${NOWHERE_MORPH_TCP_PRELUDE:-${NOWHERE_MORPH_TCP_PRELUDE_VALUE:-${NOW_MORPH_TCP_PRELUDE:-$DEFAULT_MORPH_TCP_PRELUDE}}}"
  NOWHERE_RATE="${NOWHERE_RATE:-${NOWHERE_RATE_VALUE:-0}}"; NOWHERE_ETAR="${NOWHERE_ETAR:-${NOWHERE_ETAR_VALUE:-0}}"
  NOWHERE_DIAL="${NOWHERE_DIAL:-${NOWHERE_DIAL_VALUE:-auto}}"; NOWHERE_DIAL4="${NOWHERE_DIAL4:-${NOWHERE_DIAL4_VALUE:-auto}}"; NOWHERE_DIAL6="${NOWHERE_DIAL6:-${NOWHERE_DIAL6_VALUE:-auto}}"; NOWHERE_SOCKS="${NOWHERE_SOCKS:-${NOWHERE_SOCKS_VALUE:-$DEFAULT_SOCKS}}"
  if [[ "$DIAL_EXPLICIT" -eq 0 && ( "$DIAL4_EXPLICIT" -eq 1 || "$DIAL6_EXPLICIT" -eq 1 ) ]]; then NOWHERE_DIAL=auto; fi
  NOWHERE_NEXT="${NOWHERE_NEXT:-${NOWHERE_NEXT_VALUE:-none}}"; NOWHERE_NEXT_UP="${NOWHERE_NEXT_UP:-${NOWHERE_NEXT_UP_VALUE:-tcp}}"; NOWHERE_NEXT_DOWN="${NOWHERE_NEXT_DOWN:-${NOWHERE_NEXT_DOWN_VALUE:-tcp}}"
  NOWHERE_NEXT_MUX="${NOWHERE_NEXT_MUX:-${NOWHERE_NEXT_MUX_VALUE:-$DEFAULT_MUX}}"; NOWHERE_NEXT_SNI="${NOWHERE_NEXT_SNI:-${NOWHERE_NEXT_SNI_VALUE:-$DEFAULT_SNI}}"; NOWHERE_NEXT_PIN="${NOWHERE_NEXT_PIN:-${NOWHERE_NEXT_PIN_VALUE:-$DEFAULT_PIN}}"
  NOWHERE_VECTOR_UP="${NOWHERE_VECTOR_UP:-${NOWHERE_VECTOR_UP_VALUE:-tcp}}"; NOWHERE_VECTOR_DOWN="${NOWHERE_VECTOR_DOWN:-${NOWHERE_VECTOR_DOWN_VALUE:-tcp}}"
  NOWHERE_VECTOR_MUX="${NOWHERE_VECTOR_MUX:-${NOWHERE_VECTOR_MUX_VALUE:-$DEFAULT_MUX}}"; NOWHERE_VECTOR_SOCKS="${NOWHERE_VECTOR_SOCKS:-${NOWHERE_VECTOR_SOCKS_VALUE:-$DEFAULT_VECTOR_SOCKS}}"
  NOWHERE_VECTOR_SNI="${NOWHERE_VECTOR_SNI:-${NOWHERE_VECTOR_SNI_VALUE:-$DEFAULT_SNI}}"; NOWHERE_VECTOR_PIN="${NOWHERE_VECTOR_PIN:-${NOWHERE_VECTOR_PIN_VALUE:-$DEFAULT_PIN}}"
  NOWHERE_VECTOR_RATE="${NOWHERE_VECTOR_RATE:-${NOWHERE_VECTOR_RATE_VALUE:-0}}"; NOWHERE_VECTOR_ETAR="${NOWHERE_VECTOR_ETAR:-${NOWHERE_VECTOR_ETAR_VALUE:-0}}"; NOWHERE_VECTOR_LOG="${NOWHERE_VECTOR_LOG:-${NOWHERE_VECTOR_LOG_VALUE:-$DEFAULT_LOG}}"
  NOWHERE_LOG="${NOWHERE_LOG:-${NOWHERE_LOG_VALUE:-$DEFAULT_LOG}}"; NOWHERE_TRANSPORT_MEMORY_PROFILE="${NOWHERE_TRANSPORT_MEMORY_PROFILE:-${NOWHERE_TRANSPORT_MEMORY_PROFILE_VALUE:-${NOW_TRANSPORT_MEMORY_PROFILE:-$DEFAULT_TRANSPORT_MEMORY_PROFILE}}}"
  NOWHERE_MIX_FALLBACK_TIMEOUT="${NOWHERE_MIX_FALLBACK_TIMEOUT:-${NOWHERE_MIX_FALLBACK_TIMEOUT_VALUE:-${NOW_MIX_FALLBACK_TIMEOUT:-$DEFAULT_MIX_FALLBACK_TIMEOUT}}}"
  NOWHERE_TELEMETRY_INTERVAL="${NOWHERE_TELEMETRY_INTERVAL:-${NOWHERE_TELEMETRY_INTERVAL_VALUE:-${NOW_TELEMETRY_INTERVAL:-$DEFAULT_TELEMETRY_INTERVAL}}}"
  normalize_removed_event_logs

  if [[ "$ASSUME_YES" -eq 0 ]]; then
    is_chinese && info "Nowhere 配置向导。直接回车保留默认值。" || info "Nowhere configuration wizard. Press Enter to keep defaults."
    NOWHERE_CLIENT="$(prompt_value "Client output anywhere/vector/both" "客户端输出 anywhere/vector/both" "$NOWHERE_CLIENT")"
    NOWHERE_PUBLIC_HOST="$(prompt_value "Public domain/IP" "公网域名或 IP" "$NOWHERE_PUBLIC_HOST")"
    if [[ "$NOWHERE_CLIENT" == anywhere || "$NOWHERE_CLIENT" == both ]]; then NOWHERE_ANYWHERE_SNI="$(prompt_value "Anywhere SNI (none=use public host)" "Anywhere SNI（none=使用链接主机名）" "$NOWHERE_ANYWHERE_SNI")"; fi
    NOWHERE_LISTEN_HOST="$(prompt_value "Listen host, empty means wildcard" "监听地址，留空监听全部地址" "$NOWHERE_LISTEN_HOST")"
    NOWHERE_TCP_CARRIER="$(prompt_value "TCP carrier tcp/tcp4/tcp6/none" "TCP 载体 tcp/tcp4/tcp6/none" "$NOWHERE_TCP_CARRIER")"
    [[ "$NOWHERE_TCP_CARRIER" == none ]] || NOWHERE_TCP_PORT="$(prompt_value "TCP port" "TCP 端口" "$NOWHERE_TCP_PORT")"
    NOWHERE_UDP_CARRIER="$(prompt_value "UDP carrier udp/udp4/udp6/none" "UDP 载体 udp/udp4/udp6/none" "$NOWHERE_UDP_CARRIER")"
    [[ "$NOWHERE_UDP_CARRIER" == none ]] || NOWHERE_UDP_PORT="$(prompt_value "UDP port" "UDP 端口" "$NOWHERE_UDP_PORT")"
    NOWHERE_KEY="$(prompt_value "Shared Key" "共享密钥" "$NOWHERE_KEY")"; NOWHERE_TLS="$(prompt_value "TLS 1=self-signed, 2=PEM" "TLS 1=自签证书，2=PEM 证书" "$NOWHERE_TLS")"
    if [[ "$NOWHERE_TLS" == 2 ]]; then NOWHERE_CRT="$(prompt_value "Certificate chain absolute path" "证书链绝对路径" "$NOWHERE_CRT")"; NOWHERE_TLS_KEY="$(prompt_value "Private key absolute path" "私钥绝对路径" "$NOWHERE_TLS_KEY")"; fi
    NOWHERE_MORPH="$(prompt_value "Morph 0=off, 1=ChaCha20 transform" "Morph 0=关闭，1=ChaCha20 变换" "$NOWHERE_MORPH")"
    [[ "$NOWHERE_MORPH" != 1 ]] || NOWHERE_MORPH_TCP_PRELUDE="$(prompt_value "TCP Morph prelude low7/full8 (native next only)" "TCP Morph 前导 low7/full8（仅原生 next）" "$NOWHERE_MORPH_TCP_PRELUDE")"
    NOWHERE_RATE="$(prompt_value "Rate Mbps, 0=unlimited" "限速 Mbps，0=不限速" "$NOWHERE_RATE")"; NOWHERE_ETAR="$(prompt_value "Etar Mbps, 0=unlimited" "Etar Mbps，0=不限速" "$NOWHERE_ETAR")"
    NOWHERE_DIAL="$(prompt_value "Outbound source IP (dial), auto=system default" "出站源 IP（dial），auto=系统默认" "$NOWHERE_DIAL")"
    [[ "$NOWHERE_DIAL" == auto ]] || DIAL_EXPLICIT=1
    if [[ "$NOWHERE_DIAL" != auto ]]; then NOWHERE_DIAL4=auto; NOWHERE_DIAL6=auto; fi
    if [[ "$NOWHERE_DIAL" == auto && "$DIAL_EXPLICIT" -eq 0 ]]; then
      NOWHERE_DIAL4="$(prompt_value "IPv4 outbound source (dial4)" "IPv4 出站源地址（dial4）" "$NOWHERE_DIAL4")"
      NOWHERE_DIAL6="$(prompt_value "IPv6 outbound source (dial6)" "IPv6 出站源地址（dial6）" "$NOWHERE_DIAL6")"
    fi
    path=direct
    if [[ "$NOWHERE_NEXT" != none ]]; then path=next; elif [[ "$NOWHERE_SOCKS" != none ]]; then path=socks; fi
    path="$(prompt_value "Outbound path direct/socks/next" "出站路径 direct/socks/next" "$path")"
    case "$path" in direct) NOWHERE_SOCKS=none; NOWHERE_NEXT=none ;; socks) NOWHERE_NEXT=none; NOWHERE_SOCKS="$(prompt_value "Outbound SOCKS5" "出站 SOCKS5" "$NOWHERE_SOCKS")" ;; next) NOWHERE_SOCKS=none; NOWHERE_NEXT="$(prompt_value "Next key@endpoint" "下一跳 key@endpoint" "$NOWHERE_NEXT")"; NOWHERE_NEXT_UP="$(prompt_value "Next up tcp/udp/mix" "下一跳上行 tcp/udp/mix" "$NOWHERE_NEXT_UP")"; NOWHERE_NEXT_DOWN="$(prompt_value "Next down tcp/udp/mix" "下一跳下行 tcp/udp/mix" "$NOWHERE_NEXT_DOWN")"; NOWHERE_NEXT_MUX="$(prompt_value "Next Mux 0/1" "下一跳 Mux 0/1" "$NOWHERE_NEXT_MUX")"; NOWHERE_NEXT_SNI="$(prompt_value "Next SNI/none" "下一跳 SNI/none" "$NOWHERE_NEXT_SNI")"; NOWHERE_NEXT_PIN="$(prompt_value "Next certificate pin/none" "下一跳证书 Pin/none" "$NOWHERE_NEXT_PIN")" ;; *) die "Outbound path must be direct, socks, or next." ;; esac
    NOWHERE_LOG="$(prompt_value "Log level" "日志级别" "$NOWHERE_LOG")"; NOWHERE_TRANSPORT_MEMORY_PROFILE="$(prompt_value "Transport memory memory/balanced/throughput" "传输内存 memory/balanced/throughput" "$NOWHERE_TRANSPORT_MEMORY_PROFILE")"; NOWHERE_MIX_FALLBACK_TIMEOUT="$(prompt_value "Mix fallback timeout" "Mix 回退超时" "$NOWHERE_MIX_FALLBACK_TIMEOUT")"; NOWHERE_TELEMETRY_INTERVAL="$(prompt_value "TUI telemetry interval" "TUI 遥测间隔" "$NOWHERE_TELEMETRY_INTERVAL")"
    if [[ "$NOWHERE_CLIENT" == vector || "$NOWHERE_CLIENT" == both ]]; then NOWHERE_VECTOR_UP="$(prompt_value "Vector up tcp/udp/mix" "Vector 上行 tcp/udp/mix" "$NOWHERE_VECTOR_UP")"; NOWHERE_VECTOR_DOWN="$(prompt_value "Vector down tcp/udp/mix" "Vector 下行 tcp/udp/mix" "$NOWHERE_VECTOR_DOWN")"; NOWHERE_VECTOR_MUX="$(prompt_value "Vector Mux 0/1" "Vector Mux 0/1" "$NOWHERE_VECTOR_MUX")"; NOWHERE_VECTOR_SOCKS="$(prompt_value "Vector local SOCKS5" "Vector 本地 SOCKS5" "$NOWHERE_VECTOR_SOCKS")"; NOWHERE_VECTOR_SNI="$(prompt_value "Vector SNI/none" "Vector SNI/none" "$NOWHERE_VECTOR_SNI")"; NOWHERE_VECTOR_PIN="$(prompt_value "Vector certificate pin/none" "Vector 证书 Pin/none" "$NOWHERE_VECTOR_PIN")"; NOWHERE_VECTOR_RATE="$(prompt_value "Vector rate Mbps, 0=unlimited" "Vector 限速 Mbps，0=不限速" "$NOWHERE_VECTOR_RATE")"; NOWHERE_VECTOR_ETAR="$(prompt_value "Vector etar Mbps, 0=unlimited" "Vector Etar Mbps，0=不限速" "$NOWHERE_VECTOR_ETAR")"; NOWHERE_VECTOR_LOG="$(prompt_value "Vector log level" "Vector 日志级别" "$NOWHERE_VECTOR_LOG")"; fi
  fi
  migrate_shared_key_for_version "$NOWHERE_VERSION" || return 1
  validate_config
  NOWHERE_PORTAL="$(build_portal_url)"
  NOWHERE_SERVICE_URL="$NOWHERE_PORTAL"
}

validate_nw3_config() {
  require_deployable_version "$NOWHERE_VERSION"
  validate_nw3_key "$NOWHERE_KEY" || die "NW3 shared keys must be exactly 32 lowercase hexadecimal characters."
  validate_bool "$NOWHERE_MORPH" || die "Morph must be 0 or 1."
  case "$NOWHERE_CIPHER" in
    chacha) ;;
    aes) supports_morph_cipher "$NOWHERE_VERSION" || die "Morph AES requires v3.4.0+." ;;
    *) die "Morph cipher must be chacha or aes." ;;
  esac
  validate_morph_tcp_prelude "$NOWHERE_MORPH_TCP_PRELUDE" || die "Invalid TCP Morph prelude. fade requires NW3 v3.0.1+."
  validate_profile "$NOWHERE_TRANSPORT_MEMORY_PROFILE" || die "Invalid transport memory profile."
  validate_nonnegative_int "$NOWHERE_RATE" && validate_nonnegative_int "$NOWHERE_ETAR" || die "Rate limits must be non-negative integers."
  validate_dial_settings || die "Invalid outbound source binding; dial is exclusive with dial4/dial6."
  case "$NOWHERE_ROLE" in
    portal)
      NOWHERE_CLIENT="$(normalize_client "$NOWHERE_CLIENT")" || die "NOWHERE_CLIENT must be anywhere, vector, or both."
      [[ -n "$NOWHERE_PUBLIC_HOST" ]] || die "Portal requires a public domain or IP for client links."
      case "$NOWHERE_PUBLIC_HOST" in '*'|0.0.0.0|::|'[::]') die "Portal client links require a concrete public host." ;; esac
      validate_tcp_carrier "$NOWHERE_TCP_CARRIER" && validate_udp_carrier "$NOWHERE_UDP_CARRIER" || die "Invalid Portal carrier."
      [[ "$NOWHERE_TCP_CARRIER" != none || "$NOWHERE_UDP_CARRIER" != none ]] || die "Enable at least one Portal carrier."
      [[ "$NOWHERE_TCP_CARRIER" == none ]] || validate_port "$NOWHERE_TCP_PORT" || die "Invalid TCP port."
      [[ "$NOWHERE_UDP_CARRIER" == none ]] || validate_port "$NOWHERE_UDP_PORT" || die "Invalid UDP port."
      [[ "$NOWHERE_TLS" == 1 || "$NOWHERE_TLS" == 2 ]] || die "TLS must be 1 or 2."
      if [[ "$NOWHERE_TLS" == 2 ]]; then
        [[ -n "$NOWHERE_CRT" && -n "$NOWHERE_TLS_KEY" ]] || die "tls=2 requires crt and key paths."
        [[ -f "$NOWHERE_CRT" && -f "$NOWHERE_TLS_KEY" ]] || die "Certificate or private-key file does not exist."
      fi
      case "$NOWHERE_OUT" in
        direct) ;;
        socks) validate_vector_socks "$NOWHERE_OUT_SOCKS" || die "Invalid Portal SOCKS5 upstream." ;;
        egress)
          if [[ "$NOWHERE_UDP_CARRIER" == none ]] && ! supports_tls_egress "$NOWHERE_VERSION"; then
            die "Portal out=egress requires a QUIC/UDP listener before v3.3.0."
          fi
          [[ "$NOWHERE_DIAL" == auto && "$NOWHERE_DIAL4" == auto && "$NOWHERE_DIAL6" == auto && "$DIAL_EXPLICIT" -eq 0 && "$DIAL4_EXPLICIT" -eq 0 && "$DIAL6_EXPLICIT" -eq 0 ]] || die "Portal out=egress cannot use dial, dial4, or dial6, including explicit auto values."
          ;;
        *) die "Portal out must be direct, socks, or egress." ;;
      esac
      if [[ "$NOWHERE_CLIENT" == vector || "$NOWHERE_CLIENT" == both ]]; then
        validate_vector_socks "$NOWHERE_VECTOR_SOCKS" || die "Invalid Vector SOCKS listener."
        validate_sni "$NOWHERE_VECTOR_SNI" && validate_pin "$NOWHERE_VECTOR_PIN" || die "Invalid Vector SNI or certificate pin."
        validate_nonnegative_int "$NOWHERE_VECTOR_RATE" && validate_nonnegative_int "$NOWHERE_VECTOR_ETAR" || die "Vector rate limits must be non-negative integers."
      fi
      ;;
    egress)
      [[ -n "$NOWHERE_EGRESS_PORTAL_HOST" ]] || die "Egress requires --egress-portal-host (or an interactive Portal host)."
      case "$NOWHERE_EGRESS_PORTAL_HOST" in '*'|0.0.0.0|::|'[::]') die "Egress needs a concrete Portal host." ;; esac
      case "$NOWHERE_EGRESS_PORTAL_CARRIER" in
        udp|udp4|udp6) ;;
        tcp|tcp4|tcp6) supports_tls_egress "$NOWHERE_VERSION" || die "TLS Egress requires v3.3.0+ on Portal and Egress." ;;
        *) die "Invalid Egress Portal carrier." ;;
      esac
      validate_port "$NOWHERE_EGRESS_PORTAL_PORT" || die "Invalid Portal port for Egress."
      validate_sni "$NOWHERE_EGRESS_SNI" && validate_pin "$NOWHERE_EGRESS_PIN" || die "Invalid Egress SNI or certificate pin."
      ;;
    *) die "NW3 role must be portal or egress." ;;
  esac
}

build_nw3_service_url() {
  local host endpoint query
  query="$(nw3_morph_query "$NOWHERE_VERSION" "$NOWHERE_MORPH" "${NOWHERE_CIPHER:-chacha}")"
  if [[ "$NOWHERE_ROLE" == portal ]]; then
    host="$(format_host_for_url "$NOWHERE_LISTEN_HOST")"; [[ -n "$host" ]] || host='*'
    endpoint="$(build_endpoint "$host" "$NOWHERE_TCP_CARRIER" "$NOWHERE_TCP_PORT" "$NOWHERE_UDP_CARRIER" "$NOWHERE_UDP_PORT")"
    query="tls=${NOWHERE_TLS}&${query}"
    [[ "$NOWHERE_RATE" == 0 ]] || query="${query}&rate=${NOWHERE_RATE}"
    [[ "$NOWHERE_ETAR" == 0 ]] || query="${query}&etar=${NOWHERE_ETAR}"
    if [[ "$NOWHERE_OUT" == socks ]]; then query="${query}&out=$(encode_socks_query_value "$NOWHERE_OUT_SOCKS")"; elif [[ "$NOWHERE_OUT" == egress ]]; then query="${query}&out=egress"; fi
    if [[ "$NOWHERE_DIAL" != auto ]]; then
      query="${query}&dial=$(urlencode "$NOWHERE_DIAL")"
    else
      [[ "$NOWHERE_DIAL4" == auto ]] || query="${query}&dial4=$(urlencode "$NOWHERE_DIAL4")"
      [[ "$NOWHERE_DIAL6" == auto ]] || query="${query}&dial6=$(urlencode "$NOWHERE_DIAL6")"
    fi
    [[ "$NOWHERE_TLS" != 2 ]] || query="${query}&crt=$(urlencode "$NOWHERE_CRT")&key=$(urlencode "$NOWHERE_TLS_KEY")"
    printf 'portal://%s@%s?%s' "$NOWHERE_KEY" "$endpoint" "$query"
  else
    host="$(format_host_for_url "$NOWHERE_EGRESS_PORTAL_HOST")"
    endpoint="${host}/${NOWHERE_EGRESS_PORTAL_CARRIER}:${NOWHERE_EGRESS_PORTAL_PORT}"
    [[ "$NOWHERE_EGRESS_SNI" == none ]] || query="${query}&sni=$(urlencode "$NOWHERE_EGRESS_SNI")"
    [[ "$NOWHERE_EGRESS_PIN" == none ]] || query="${query}&pin=${NOWHERE_EGRESS_PIN}"
    if [[ "$NOWHERE_DIAL" != auto ]]; then
      query="${query}&dial=$(urlencode "$NOWHERE_DIAL")"
    else
      [[ "$NOWHERE_DIAL4" == auto ]] || query="${query}&dial4=$(urlencode "$NOWHERE_DIAL4")"
      [[ "$NOWHERE_DIAL6" == auto ]] || query="${query}&dial6=$(urlencode "$NOWHERE_DIAL6")"
    fi
    [[ "$NOWHERE_RATE" == 0 ]] || query="${query}&rate=${NOWHERE_RATE}"
    [[ "$NOWHERE_ETAR" == 0 ]] || query="${query}&etar=${NOWHERE_ETAR}"
    printf 'egress://%s@%s?%s' "$NOWHERE_KEY" "$endpoint" "$query"
  fi
}

configure_nw3_values() {
  local generated_key="$1" detected_host="$2" role_default default_morph previous_role role_changed=0
  [[ "${NOWHERE_NEXT:-none}" == none ]] || die "NW3 removes native next; use --out egress or another supported Portal output."
  previous_role="${NOWHERE_ROLE_VALUE:-portal}"
  role_default="${NOWHERE_ROLE:-${NOWHERE_ROLE_VALUE:-portal}}"
  NOWHERE_ROLE="$role_default"
  if [[ "$ROLE_EXPLICIT" -eq 0 && "$ASSUME_YES" -eq 0 ]]; then
    NOWHERE_ROLE="$(prompt_value "Service role portal/egress" "服务角色 portal/egress" "$NOWHERE_ROLE")"
  fi
  [[ "$NOWHERE_ROLE" == portal || "$NOWHERE_ROLE" == egress ]] || die "NW3 role must be portal or egress."
  [[ "$NOWHERE_ROLE" == "$previous_role" ]] || role_changed=1

  if [[ -n "${NOWHERE_MORPH:-}" ]]; then
    default_morph="$NOWHERE_MORPH"
  elif is_nw3_version "${NOWHERE_VERSION_VALUE:-}"; then
    default_morph="${NOWHERE_MORPH_VALUE:-1}"
  else
    default_morph=1
  fi
  NOWHERE_MORPH="$default_morph"
  NOWHERE_CIPHER="${NOWHERE_CIPHER:-${NOWHERE_CIPHER_VALUE:-chacha}}"
  NOWHERE_KEY="${NOWHERE_KEY:-${NOWHERE_KEY_VALUE:-$generated_key}}"
  if ! validate_nw3_key "$NOWHERE_KEY"; then
    [[ "$KEY_EXPLICIT" -eq 0 && -n "${NOWHERE_KEY_VALUE:-}" ]] || die "NW3 shared keys must be exactly 32 lowercase hexadecimal characters."
    migrate_shared_key_for_version "$NOWHERE_VERSION" || return 1
  fi
  NOWHERE_RATE="${NOWHERE_RATE:-${NOWHERE_RATE_VALUE:-0}}"
  NOWHERE_ETAR="${NOWHERE_ETAR:-${NOWHERE_ETAR_VALUE:-0}}"
  NOWHERE_DIAL="${NOWHERE_DIAL:-${NOWHERE_DIAL_VALUE:-auto}}"
  NOWHERE_DIAL4="${NOWHERE_DIAL4:-${NOWHERE_DIAL4_VALUE:-auto}}"
  NOWHERE_DIAL6="${NOWHERE_DIAL6:-${NOWHERE_DIAL6_VALUE:-auto}}"
  if [[ "$DIAL_EXPLICIT" -eq 0 && ( "$DIAL4_EXPLICIT" -eq 1 || "$DIAL6_EXPLICIT" -eq 1 ) ]]; then NOWHERE_DIAL=auto; fi
  NOWHERE_CLIENT="${NOWHERE_CLIENT:-${NOWHERE_CLIENT_VALUE:-$DEFAULT_CLIENT}}"
  NOWHERE_VECTOR_SOCKS="${NOWHERE_VECTOR_SOCKS:-${NOWHERE_VECTOR_SOCKS_VALUE:-$DEFAULT_VECTOR_SOCKS}}"
  NOWHERE_VECTOR_SNI="${NOWHERE_VECTOR_SNI:-${NOWHERE_VECTOR_SNI_VALUE:-$DEFAULT_SNI}}"
  NOWHERE_VECTOR_PIN="${NOWHERE_VECTOR_PIN:-${NOWHERE_VECTOR_PIN_VALUE:-$DEFAULT_PIN}}"
  NOWHERE_VECTOR_RATE="${NOWHERE_VECTOR_RATE:-${NOWHERE_VECTOR_RATE_VALUE:-0}}"
  NOWHERE_VECTOR_ETAR="${NOWHERE_VECTOR_ETAR:-${NOWHERE_VECTOR_ETAR_VALUE:-0}}"

  if [[ "$NOWHERE_ROLE" == portal ]]; then
    if [[ "$role_changed" -eq 1 ]]; then
      [[ "$PUBLIC_HOST_EXPLICIT" -eq 1 ]] || NOWHERE_PUBLIC_HOST="$detected_host"
      [[ "$LISTEN_HOST_EXPLICIT" -eq 1 ]] || NOWHERE_LISTEN_HOST=""
      [[ "$TCP_CARRIER_EXPLICIT" -eq 1 ]] || NOWHERE_TCP_CARRIER="$DEFAULT_TCP_CARRIER"
      [[ "$TCP_PORT_EXPLICIT" -eq 1 ]] || NOWHERE_TCP_PORT="$DEFAULT_PORT"
      [[ "$UDP_CARRIER_EXPLICIT" -eq 1 ]] || NOWHERE_UDP_CARRIER="$DEFAULT_UDP_CARRIER"
      [[ "$UDP_PORT_EXPLICIT" -eq 1 ]] || NOWHERE_UDP_PORT="$DEFAULT_PORT"
    else
      NOWHERE_PUBLIC_HOST="${NOWHERE_PUBLIC_HOST:-${NOWHERE_PUBLIC_HOST_VALUE:-$detected_host}}"
      NOWHERE_TCP_CARRIER="${NOWHERE_TCP_CARRIER:-${NOWHERE_TCP_CARRIER_VALUE:-$DEFAULT_TCP_CARRIER}}"
      NOWHERE_TCP_PORT="${NOWHERE_TCP_PORT:-${NOWHERE_TCP_PORT_VALUE:-$DEFAULT_PORT}}"
      NOWHERE_UDP_CARRIER="${NOWHERE_UDP_CARRIER:-${NOWHERE_UDP_CARRIER_VALUE:-$DEFAULT_UDP_CARRIER}}"
      NOWHERE_UDP_PORT="${NOWHERE_UDP_PORT:-${NOWHERE_UDP_PORT_VALUE:-$DEFAULT_PORT}}"
    fi
    [[ "$role_changed" -eq 1 ]] || NOWHERE_LISTEN_HOST="${NOWHERE_LISTEN_HOST:-${NOWHERE_LISTEN_HOST_VALUE:-}}"
    NOWHERE_CRT="${NOWHERE_CRT:-${NOWHERE_CRT_VALUE:-}}"
    NOWHERE_TLS_KEY="${NOWHERE_TLS_KEY:-${NOWHERE_TLS_KEY_VALUE:-}}"
    NOWHERE_TLS="${NOWHERE_TLS:-${NOWHERE_TLS_VALUE:-$DEFAULT_TLS}}"
    if [[ -n "${NOWHERE_OUT:-}" || "$OUT_EXPLICIT" -eq 1 ]]; then
      NOWHERE_OUT="${NOWHERE_OUT:-${NOWHERE_OUT_VALUE:-direct}}"
    elif ! is_nw3_version "${NOWHERE_VERSION_VALUE:-$NOWHERE_VERSION}" && [[ "${NOWHERE_NEXT_VALUE:-none}" != none ]]; then
      NOWHERE_OUT=none
      warn "NW3 removes native next; select a replacement Portal output."
    elif ! is_nw3_version "${NOWHERE_VERSION_VALUE:-$NOWHERE_VERSION}" && [[ "${NOWHERE_SOCKS_VALUE:-none}" != none ]]; then
      NOWHERE_OUT=socks
    else
      NOWHERE_OUT="${NOWHERE_OUT_VALUE:-direct}"
    fi
    NOWHERE_OUT_SOCKS="${NOWHERE_OUT_SOCKS:-${NOWHERE_OUT_SOCKS_VALUE:-${NOWHERE_SOCKS_VALUE:-none}}}"
    if [[ "${NOWHERE_SOCKS:-none}" != none && "$OUT_EXPLICIT" -eq 0 ]]; then NOWHERE_OUT=socks; NOWHERE_OUT_SOCKS="$NOWHERE_SOCKS"; fi
  else
    NOWHERE_EGRESS_PORTAL_HOST="${NOWHERE_EGRESS_PORTAL_HOST:-${NOWHERE_EGRESS_PORTAL_HOST_VALUE:-}}"
    NOWHERE_EGRESS_PORTAL_CARRIER="${NOWHERE_EGRESS_PORTAL_CARRIER:-${NOWHERE_EGRESS_PORTAL_UDP_CARRIER:-${NOWHERE_EGRESS_PORTAL_CARRIER_VALUE:-${NOWHERE_EGRESS_PORTAL_UDP_CARRIER_VALUE:-udp}}}}"
    NOWHERE_EGRESS_PORTAL_PORT="${NOWHERE_EGRESS_PORTAL_PORT:-${NOWHERE_EGRESS_PORTAL_UDP_PORT:-${NOWHERE_EGRESS_PORTAL_PORT_VALUE:-${NOWHERE_EGRESS_PORTAL_UDP_PORT_VALUE:-$DEFAULT_PORT}}}}"
    NOWHERE_EGRESS_SNI="${NOWHERE_EGRESS_SNI:-${NOWHERE_EGRESS_SNI_VALUE:-none}}"
    NOWHERE_EGRESS_PIN="${NOWHERE_EGRESS_PIN:-${NOWHERE_EGRESS_PIN_VALUE:-$DEFAULT_PIN}}"
  fi
  NOWHERE_PUBLIC_HOST="${NOWHERE_PUBLIC_HOST:-${NOWHERE_EGRESS_PORTAL_HOST:-$detected_host}}"
  NOWHERE_ANYWHERE_SNI="${NOWHERE_ANYWHERE_SNI:-none}"
  NOWHERE_LISTEN_HOST="${NOWHERE_LISTEN_HOST:-}"
  NOWHERE_TCP_CARRIER="${NOWHERE_TCP_CARRIER:-none}"; NOWHERE_TCP_PORT="${NOWHERE_TCP_PORT:-$DEFAULT_PORT}"
  NOWHERE_UDP_CARRIER="${NOWHERE_UDP_CARRIER:-none}"; NOWHERE_UDP_PORT="${NOWHERE_UDP_PORT:-$DEFAULT_PORT}"
  NOWHERE_TLS="${NOWHERE_TLS:-$DEFAULT_TLS}"; NOWHERE_CRT="${NOWHERE_CRT:-}"; NOWHERE_TLS_KEY="${NOWHERE_TLS_KEY:-}"
  NOWHERE_MORPH_TCP_PRELUDE="${NOWHERE_MORPH_TCP_PRELUDE:-${NOWHERE_MORPH_TCP_PRELUDE_VALUE:-${NOW_MORPH_TCP_PRELUDE:-$(default_morph_tcp_prelude "$NOWHERE_VERSION")}}}"
  NOWHERE_SOCKS="${NOWHERE_SOCKS:-${NOWHERE_OUT_SOCKS:-none}}"
  NOWHERE_NEXT="${NOWHERE_NEXT:-none}"; NOWHERE_NEXT_UP="${NOWHERE_NEXT_UP:-tcp}"; NOWHERE_NEXT_DOWN="${NOWHERE_NEXT_DOWN:-tcp}"
  NOWHERE_NEXT_MUX="${NOWHERE_NEXT_MUX:-$DEFAULT_MUX}"; NOWHERE_NEXT_SNI="${NOWHERE_NEXT_SNI:-$DEFAULT_SNI}"; NOWHERE_NEXT_PIN="${NOWHERE_NEXT_PIN:-$DEFAULT_PIN}"
  NOWHERE_VECTOR_UP="${NOWHERE_VECTOR_UP:-tcp}"; NOWHERE_VECTOR_DOWN="${NOWHERE_VECTOR_DOWN:-tcp}"; NOWHERE_VECTOR_MUX="${NOWHERE_VECTOR_MUX:-$DEFAULT_MUX}"
  NOWHERE_VECTOR_LOG="${NOWHERE_VECTOR_LOG:-$DEFAULT_LOG}"; NOWHERE_LOG="${NOWHERE_LOG:-$DEFAULT_LOG}"
  NOWHERE_TRANSPORT_MEMORY_PROFILE="${NOWHERE_TRANSPORT_MEMORY_PROFILE:-${NOWHERE_TRANSPORT_MEMORY_PROFILE_VALUE:-${NOW_TRANSPORT_MEMORY_PROFILE:-$DEFAULT_TRANSPORT_MEMORY_PROFILE}}}"
  NOWHERE_MIX_FALLBACK_TIMEOUT="${NOWHERE_MIX_FALLBACK_TIMEOUT:-$DEFAULT_MIX_FALLBACK_TIMEOUT}"
  NOWHERE_TELEMETRY_INTERVAL="${NOWHERE_TELEMETRY_INTERVAL:-$DEFAULT_TELEMETRY_INTERVAL}"

  if [[ "$ASSUME_YES" -eq 0 ]]; then
    is_chinese && info "NW3 配置向导。直接回车保留默认值。" || info "NW3 configuration wizard. Press Enter to keep defaults."
    if [[ "$NOWHERE_ROLE" == portal ]]; then
      NOWHERE_CLIENT="$(prompt_value "Client output anywhere/vector/both" "客户端输出 anywhere/vector/both" "$NOWHERE_CLIENT")"
      NOWHERE_PUBLIC_HOST="$(prompt_value "Public domain/IP" "公网域名或 IP" "$NOWHERE_PUBLIC_HOST")"
      NOWHERE_LISTEN_HOST="$(prompt_value "Listen host, empty means wildcard" "监听地址，留空监听全部地址" "$NOWHERE_LISTEN_HOST")"
      NOWHERE_TCP_CARRIER="$(prompt_value "TCP carrier tcp/tcp4/tcp6/none" "TCP 载体 tcp/tcp4/tcp6/none" "$NOWHERE_TCP_CARRIER")"
      [[ "$NOWHERE_TCP_CARRIER" == none ]] || NOWHERE_TCP_PORT="$(prompt_value "TCP port" "TCP 端口" "$NOWHERE_TCP_PORT")"
      NOWHERE_UDP_CARRIER="$(prompt_value "UDP carrier udp/udp4/udp6/none" "UDP 载体 udp/udp4/udp6/none" "$NOWHERE_UDP_CARRIER")"
      [[ "$NOWHERE_UDP_CARRIER" == none ]] || NOWHERE_UDP_PORT="$(prompt_value "UDP port" "UDP 端口" "$NOWHERE_UDP_PORT")"
      NOWHERE_KEY="$(prompt_value "Shared Key (32 lowercase hex)" "共享密钥（32 位小写十六进制）" "$NOWHERE_KEY")"
      NOWHERE_TLS="$(prompt_value "TLS 1=self-signed, 2=PEM" "TLS 1=自签证书，2=PEM 证书" "$NOWHERE_TLS")"
      if [[ "$NOWHERE_TLS" == 2 ]]; then NOWHERE_CRT="$(prompt_value "Certificate chain absolute path" "证书链绝对路径" "$NOWHERE_CRT")"; NOWHERE_TLS_KEY="$(prompt_value "Private key absolute path" "私钥绝对路径" "$NOWHERE_TLS_KEY")"; fi
      NOWHERE_MORPH="$(prompt_value "Morph 0=off, 1=on" "Morph 0=关闭，1=开启" "$NOWHERE_MORPH")"
      prompt_morph_cipher
      [[ "$NOWHERE_MORPH" != 1 ]] || NOWHERE_MORPH_TCP_PRELUDE="$(prompt_value "TCP Morph prelude fade/low7/full8 (fade: 3.0.1+)" "TCP Morph 前导 fade/low7/full8（fade: 3.0.1+）" "$NOWHERE_MORPH_TCP_PRELUDE")"
      NOWHERE_RATE="$(prompt_value "Rate Mbps, 0=unlimited" "限速 Mbps，0=不限速" "$NOWHERE_RATE")"
      NOWHERE_ETAR="$(prompt_value "Etar Mbps, 0=unlimited" "Etar Mbps，0=不限速" "$NOWHERE_ETAR")"
      NOWHERE_OUT="$(prompt_value "Portal out direct/socks/egress" "Portal 出口 direct/socks/egress" "$NOWHERE_OUT")"
      if [[ "$NOWHERE_OUT" == socks ]]; then NOWHERE_OUT_SOCKS="$(prompt_value "Outbound SOCKS5" "出站 SOCKS5" "$NOWHERE_OUT_SOCKS")"; fi
      if [[ "$NOWHERE_OUT" == egress ]]; then
        [[ "$DIAL_EXPLICIT" -eq 1 || "$DIAL4_EXPLICIT" -eq 1 || "$DIAL6_EXPLICIT" -eq 1 ]] || { NOWHERE_DIAL=auto; NOWHERE_DIAL4=auto; NOWHERE_DIAL6=auto; }
      else
        NOWHERE_DIAL="$(prompt_value "Outbound source IP (dial), auto=system default" "出站源 IP（dial），auto=系统默认" "$NOWHERE_DIAL")"
        [[ "$NOWHERE_DIAL" == auto ]] || DIAL_EXPLICIT=1
        if [[ "$NOWHERE_DIAL" != auto ]]; then NOWHERE_DIAL4=auto; NOWHERE_DIAL6=auto; fi
        if [[ "$NOWHERE_DIAL" == auto && "$DIAL_EXPLICIT" -eq 0 ]]; then
          NOWHERE_DIAL4="$(prompt_value "IPv4 outbound source (dial4)" "IPv4 出站源地址（dial4）" "$NOWHERE_DIAL4")"
          NOWHERE_DIAL6="$(prompt_value "IPv6 outbound source (dial6)" "IPv6 出站源地址（dial6）" "$NOWHERE_DIAL6")"
        fi
      fi
      if [[ "$NOWHERE_CLIENT" == vector || "$NOWHERE_CLIENT" == both ]]; then
        NOWHERE_VECTOR_SOCKS="$(prompt_value "Vector local SOCKS5 listener" "Vector 本地 SOCKS5 监听地址" "$NOWHERE_VECTOR_SOCKS")"
        NOWHERE_VECTOR_SNI="$(prompt_value "Vector SNI/none" "Vector SNI/none" "$NOWHERE_VECTOR_SNI")"
        NOWHERE_VECTOR_PIN="$(prompt_value "Vector certificate pin/none" "Vector 证书 Pin/none" "$NOWHERE_VECTOR_PIN")"
        NOWHERE_VECTOR_RATE="$(prompt_value "Vector rate Mbps, 0=unlimited" "Vector 限速 Mbps，0=不限速" "$NOWHERE_VECTOR_RATE")"
        NOWHERE_VECTOR_ETAR="$(prompt_value "Vector etar Mbps, 0=unlimited" "Vector Etar Mbps，0=不限速" "$NOWHERE_VECTOR_ETAR")"
      fi
    else
      NOWHERE_EGRESS_PORTAL_HOST="$(prompt_value "Portal public host" "Portal 公网域名或 IP" "$NOWHERE_EGRESS_PORTAL_HOST")"
      if supports_tls_egress "$NOWHERE_VERSION"; then
        NOWHERE_EGRESS_PORTAL_CARRIER="$(prompt_value "Portal carrier udp/udp4/udp6/tcp/tcp4/tcp6 (TLS requires v3.3.0+ on both peers)" "Portal 载体 udp/udp4/udp6/tcp/tcp4/tcp6（TLS 要求两端 v3.3.0+）" "$NOWHERE_EGRESS_PORTAL_CARRIER")"
      else
        NOWHERE_EGRESS_PORTAL_CARRIER="$(prompt_value "Portal UDP carrier udp/udp4/udp6" "Portal UDP 载体 udp/udp4/udp6" "$NOWHERE_EGRESS_PORTAL_CARRIER")"
      fi
      NOWHERE_EGRESS_PORTAL_PORT="$(prompt_value "Portal port" "Portal 端口" "$NOWHERE_EGRESS_PORTAL_PORT")"
      NOWHERE_KEY="$(prompt_value "Shared Key (same as Portal, 32 lowercase hex)" "共享密钥（与 Portal 相同，32 位小写十六进制）" "$NOWHERE_KEY")"
      NOWHERE_MORPH="$(prompt_value "Morph 0=off, 1=on" "Morph 0=关闭，1=开启" "$NOWHERE_MORPH")"
      prompt_morph_cipher
      NOWHERE_EGRESS_SNI="$(prompt_value "Portal SNI/none" "Portal SNI/none" "$NOWHERE_EGRESS_SNI")"
      NOWHERE_EGRESS_PIN="$(prompt_value "Portal certificate pin/none" "Portal 证书 Pin/none" "$NOWHERE_EGRESS_PIN")"
      NOWHERE_DIAL="$(prompt_value "Target source IP (dial), auto=system default" "目标出站源 IP（dial），auto=系统默认" "$NOWHERE_DIAL")"
      [[ "$NOWHERE_DIAL" == auto ]] || DIAL_EXPLICIT=1
      if [[ "$NOWHERE_DIAL" != auto ]]; then NOWHERE_DIAL4=auto; NOWHERE_DIAL6=auto; fi
      if [[ "$NOWHERE_DIAL" == auto && "$DIAL_EXPLICIT" -eq 0 ]]; then
        NOWHERE_DIAL4="$(prompt_value "IPv4 target source (dial4)" "IPv4 目标源地址（dial4）" "$NOWHERE_DIAL4")"
        NOWHERE_DIAL6="$(prompt_value "IPv6 target source (dial6)" "IPv6 目标源地址（dial6）" "$NOWHERE_DIAL6")"
      fi
      NOWHERE_RATE="$(prompt_value "Rate Mbps, 0=unlimited" "限速 Mbps，0=不限速" "$NOWHERE_RATE")"
      NOWHERE_ETAR="$(prompt_value "Etar Mbps, 0=unlimited" "Etar Mbps，0=不限速" "$NOWHERE_ETAR")"
    fi
    NOWHERE_TRANSPORT_MEMORY_PROFILE="$(prompt_value "Transport memory memory/balanced/throughput" "传输内存 memory/balanced/throughput" "$NOWHERE_TRANSPORT_MEMORY_PROFILE")"
  fi

  validate_nw3_config
  [[ "$NOWHERE_MORPH" != 0 ]] || NOWHERE_CIPHER=chacha
  NOWHERE_SERVICE_URL="$(build_nw3_service_url)"
  NOWHERE_PORTAL="$NOWHERE_SERVICE_URL"
}

save_config() {
  install -d -m 700 "$CONFIG_DIR"
  cat >"$CONFIG_FILE" <<EOF
NOWHERE_PORTAL=$(env_quote "$NOWHERE_PORTAL")
NOWHERE_SERVICE_URL=$(env_quote "$NOWHERE_SERVICE_URL")
NOWHERE_LANG_VALUE=$(env_quote "$NOWHERE_LANG")
NOWHERE_VERSION_VALUE=$(env_quote "$NOWHERE_VERSION")
NOWHERE_ROLE_VALUE=$(env_quote "$NOWHERE_ROLE")
NOWHERE_CLIENT_VALUE=$(env_quote "$NOWHERE_CLIENT")
NOWHERE_PUBLIC_HOST_VALUE=$(env_quote "$NOWHERE_PUBLIC_HOST")
NOWHERE_ANYWHERE_SNI_VALUE=$(env_quote "$NOWHERE_ANYWHERE_SNI")
NOWHERE_LISTEN_HOST_VALUE=$(env_quote "$NOWHERE_LISTEN_HOST")
NOWHERE_KEY_VALUE=$(env_quote "$NOWHERE_KEY")
NOWHERE_TCP_CARRIER_VALUE=$(env_quote "$NOWHERE_TCP_CARRIER")
NOWHERE_TCP_PORT_VALUE=$(env_quote "$NOWHERE_TCP_PORT")
NOWHERE_UDP_CARRIER_VALUE=$(env_quote "$NOWHERE_UDP_CARRIER")
NOWHERE_UDP_PORT_VALUE=$(env_quote "$NOWHERE_UDP_PORT")
NOWHERE_TLS_VALUE=$(env_quote "$NOWHERE_TLS")
NOWHERE_CRT_VALUE=$(env_quote "$NOWHERE_CRT")
NOWHERE_TLS_KEY_VALUE=$(env_quote "$NOWHERE_TLS_KEY")
NOWHERE_MORPH_VALUE=$(env_quote "$NOWHERE_MORPH")
NOWHERE_CIPHER_VALUE=$(env_quote "${NOWHERE_CIPHER:-chacha}")
NOWHERE_MORPH_TCP_PRELUDE_VALUE=$(env_quote "$NOWHERE_MORPH_TCP_PRELUDE")
NOW_MORPH_TCP_PRELUDE=$(env_quote "$NOWHERE_MORPH_TCP_PRELUDE")
NOWHERE_RATE_VALUE=$(env_quote "$NOWHERE_RATE")
NOWHERE_ETAR_VALUE=$(env_quote "$NOWHERE_ETAR")
NOWHERE_DIAL_VALUE=$(env_quote "$NOWHERE_DIAL")
NOWHERE_DIAL4_VALUE=$(env_quote "${NOWHERE_DIAL4:-auto}")
NOWHERE_DIAL6_VALUE=$(env_quote "${NOWHERE_DIAL6:-auto}")
NOWHERE_SOCKS_VALUE=$(env_quote "$NOWHERE_SOCKS")
NOWHERE_OUT_VALUE=$(env_quote "${NOWHERE_OUT:-direct}")
NOWHERE_OUT_SOCKS_VALUE=$(env_quote "${NOWHERE_OUT_SOCKS:-none}")
NOWHERE_EGRESS_PORTAL_HOST_VALUE=$(env_quote "${NOWHERE_EGRESS_PORTAL_HOST:-}")
NOWHERE_EGRESS_PORTAL_CARRIER_VALUE=$(env_quote "${NOWHERE_EGRESS_PORTAL_CARRIER:-udp}")
NOWHERE_EGRESS_PORTAL_PORT_VALUE=$(env_quote "${NOWHERE_EGRESS_PORTAL_PORT:-$DEFAULT_PORT}")
NOWHERE_EGRESS_PORTAL_UDP_CARRIER_VALUE=$(env_quote "${NOWHERE_EGRESS_PORTAL_CARRIER:-udp}")
NOWHERE_EGRESS_PORTAL_UDP_PORT_VALUE=$(env_quote "${NOWHERE_EGRESS_PORTAL_PORT:-$DEFAULT_PORT}")
NOWHERE_EGRESS_SNI_VALUE=$(env_quote "${NOWHERE_EGRESS_SNI:-none}")
NOWHERE_EGRESS_PIN_VALUE=$(env_quote "${NOWHERE_EGRESS_PIN:-none}")
NOWHERE_NEXT_VALUE=$(env_quote "$NOWHERE_NEXT")
NOWHERE_NEXT_UP_VALUE=$(env_quote "$NOWHERE_NEXT_UP")
NOWHERE_NEXT_DOWN_VALUE=$(env_quote "$NOWHERE_NEXT_DOWN")
NOWHERE_NEXT_MUX_VALUE=$(env_quote "$NOWHERE_NEXT_MUX")
NOWHERE_NEXT_SNI_VALUE=$(env_quote "$NOWHERE_NEXT_SNI")
NOWHERE_NEXT_PIN_VALUE=$(env_quote "$NOWHERE_NEXT_PIN")
NOWHERE_VECTOR_UP_VALUE=$(env_quote "$NOWHERE_VECTOR_UP")
NOWHERE_VECTOR_DOWN_VALUE=$(env_quote "$NOWHERE_VECTOR_DOWN")
NOWHERE_VECTOR_MUX_VALUE=$(env_quote "$NOWHERE_VECTOR_MUX")
NOWHERE_VECTOR_SOCKS_VALUE=$(env_quote "$NOWHERE_VECTOR_SOCKS")
NOWHERE_VECTOR_SNI_VALUE=$(env_quote "$NOWHERE_VECTOR_SNI")
NOWHERE_VECTOR_PIN_VALUE=$(env_quote "$NOWHERE_VECTOR_PIN")
NOWHERE_VECTOR_RATE_VALUE=$(env_quote "$NOWHERE_VECTOR_RATE")
NOWHERE_VECTOR_ETAR_VALUE=$(env_quote "$NOWHERE_VECTOR_ETAR")
NOWHERE_VECTOR_LOG_VALUE=$(env_quote "$NOWHERE_VECTOR_LOG")
NOWHERE_LOG_VALUE=$(env_quote "$NOWHERE_LOG")
NOWHERE_TRANSPORT_MEMORY_PROFILE_VALUE=$(env_quote "$NOWHERE_TRANSPORT_MEMORY_PROFILE")
NOW_TRANSPORT_MEMORY_PROFILE=$(env_quote "$NOWHERE_TRANSPORT_MEMORY_PROFILE")
NOWHERE_MIX_FALLBACK_TIMEOUT_VALUE=$(env_quote "$NOWHERE_MIX_FALLBACK_TIMEOUT")
NOW_MIX_FALLBACK_TIMEOUT=$(env_quote "$NOWHERE_MIX_FALLBACK_TIMEOUT")
NOWHERE_TELEMETRY_INTERVAL_VALUE=$(env_quote "$NOWHERE_TELEMETRY_INTERVAL")
NOW_TELEMETRY_INTERVAL=$(env_quote "$NOWHERE_TELEMETRY_INTERVAL")
EOF
  chmod 600 "$CONFIG_FILE"
}

detect_asset() {
  local arch libc=gnu
  case "$(uname -m)" in x86_64|amd64) arch=x86_64 ;; aarch64|arm64) arch=aarch64 ;; *) die "Unsupported architecture: $(uname -m)" ;; esac
  if [[ -f /etc/alpine-release ]] || compgen -G '/lib/ld-musl-*.so.1' >/dev/null; then
    libc=musl
  fi
  printf 'nowhere-%s-unknown-linux-%s.tar.gz' "$arch" "$libc"
}
install_binary() (
  local version="$1" asset url binary
  require_deployable_version "$version"; command -v curl >/dev/null 2>&1 || die "curl is required."; command -v tar >/dev/null 2>&1 || die "tar is required."
  asset="$(detect_asset)"; url="https://github.com/${REPO}/releases/download/${version}/${asset}"; tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  info "Downloading ${asset} from ${REPO} ${version}..."
  curl -fL --retry 3 --connect-timeout 10 -o "${tmpdir}/${asset}" "$url" || return 1
  tar -xzf "${tmpdir}/${asset}" -C "$tmpdir" || return 1
  binary="$(find "$tmpdir" -type f -name nowhere -print -quit)"; [[ -n "$binary" ]] || die "Nowhere binary not found in release archive."
  mkdir -p "${BIN_PATH%/*}" && install -m 755 "$binary" "$BIN_PATH"
)
service_log_path() { printf '%s/nowhere.log' "$CONFIG_DIR"; }
write_openrc_service() {
  cat >"${CONFIG_DIR}/run" <<EOF
#!/bin/sh
set -e
umask 077
exec >"$(service_log_path)" 2>&1
set -a
. "$CONFIG_FILE"
set +a
exec "$BIN_PATH" "\${NOWHERE_SERVICE_URL:-\${NOWHERE_PORTAL:?Missing Nowhere URL}}"
EOF
  chmod 700 "${CONFIG_DIR}/run"
  cat >"$SERVICE_FILE" <<EOF
#!/sbin/openrc-run
description="Nowhere"
supervisor=supervise-daemon
command="${CONFIG_DIR}/run"
respawn_delay=3
respawn_max=5
respawn_period=60

depend() {
  use net
}
EOF
  chmod 755 "$SERVICE_FILE"
}
write_service() {
  if [[ "$SERVICE_BACKEND" == openrc ]]; then
    write_openrc_service
    return
  fi
  cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Nowhere ${NOWHERE_ROLE:-portal}
Documentation=https://github.com/${REPO}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=${CONFIG_FILE}
ExecStart=${BIN_PATH} \${NOWHERE_SERVICE_URL}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=read-only
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
}
service_control() {
  if [[ "$SERVICE_BACKEND" == openrc ]]; then
    case "$1" in
      enable) rc-update add "$SERVICE_NAME" default ;;
      disable) rc-update del "$SERVICE_NAME" default ;;
      is-enabled) [[ -L "/etc/runlevels/default/$SERVICE_NAME" ]] ;;
      is-active) rc-service "$SERVICE_NAME" status >/dev/null 2>&1 ;;
      *) rc-service "$SERVICE_NAME" "$1" ;;
    esac
  else
    systemctl "$1" "$SERVICE_NAME"
  fi
}
service_state() {
  if [[ "$SERVICE_BACKEND" == openrc ]]; then
    local status=0
    rc-service "$SERVICE_NAME" status >/dev/null 2>&1 || status=$?
    case "$status" in 0) echo active ;; 3) echo inactive ;; *) echo failed ;; esac
  else
    service_control is-active
  fi
}
service_logs() {
  require_root
  if [[ "$SERVICE_BACKEND" == openrc ]]; then
    [[ -f "$(service_log_path)" ]] || die "No Nowhere log yet. Start the service first."
    tail -n 100 -F "$(service_log_path)"
  else
    journalctl -u "$SERVICE_NAME" -f
  fi
}
service_cmd() { require_root; require_service_manager; service_control "$1"; }
service_activate() {
  if [[ "$SERVICE_BACKEND" == openrc ]] && ! service_control is-active; then
    service_control start
  else
    service_control restart
  fi
}
run_nowhere_status() {
  require_supported_nowhere
  "$BIN_PATH" status
}
run_probe() {
  require_supported_nowhere
  local target="${1:-}" vector_url
  if [[ -z "$target" ]]; then
    [[ -t 0 ]] || die "Usage: sudo bash $SCRIPT_PATH probe <host:port>"
    if is_chinese; then read -r -p "TCP 目标 host:port（IPv6 使用 [地址]:端口）: " target; else read -r -p "TCP target host:port (IPv6: [address]:port): " target; fi
  fi
  if ! validate_probe_target "$target"; then
    if is_chinese; then die "目标格式无效，请输入 host:port，例如 example.com:443；IPv6 请使用 [2001:db8::1]:443。"; else die "Invalid target; use host:port (for example example.com:443) or [IPv6]:port."; fi
  fi
  vector_url="$(build_probe_vector_url)"
  if is_chinese; then info "正在探测到 ${target} 的 TCP Flow 路径..."; else info "Probing the TCP Flow path to ${target}..."; fi
  "$BIN_PATH" probe "$vector_url" "$target"
}

install_optional_package() {
  local package="$1"
  if command -v apk >/dev/null 2>&1; then
    [[ "$package" != qrencode ]] || package=libqrencode-tools
    apk add --no-cache "$package"
  elif command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq &&
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package"
  elif command -v dnf >/dev/null 2>&1; then dnf install -y "$package"
  elif command -v yum >/dev/null 2>&1; then yum install -y "$package"
  else return 1; fi
}
offer_optional_tool() {
  local tool="$1" skip="$2" prompt="$3"
  if [[ "$skip" -eq 1 ]] || command -v "$tool" >/dev/null 2>&1; then return 0; fi
  confirm_default_yes "$prompt" || return 0
  if ! install_optional_package "$tool" || ! command -v "$tool" >/dev/null 2>&1; then
    if is_chinese; then warn "可选工具 $tool 未安装，继续部署 Nowhere。"
    else warn "Optional tool $tool was not installed; continuing without it."; fi
  fi
}
offer_jq() {
  local prompt="Install jq for the live GitHub release list?"
  if is_chinese; then prompt="安装 jq 以查看 GitHub 实时版本列表？"; fi
  offer_optional_tool jq "$SKIP_JQ" "$prompt"
}
offer_qrencode() {
  local prompt="Install qrencode for Anywhere QR codes?"
  if is_chinese; then prompt="安装二维码工具以输出 Anywhere 导入二维码？"; fi
  offer_optional_tool qrencode "$SKIP_QRENCODE" "$prompt"
}
print_qr_code() { [[ -n "$1" ]] && command -v qrencode >/dev/null 2>&1 || return 0; echo; echo "QR code (Anywhere nowhere:// link):"; qrencode -t ANSIUTF8 -m 1 -s 1 "$1" || warn "QR rendering failed."; }

print_links() {
  require_root; load_config; [[ -n "${NOWHERE_KEY_VALUE:-}" ]] || die "No configuration found."
  local host endpoint anywhere_endpoint key name base tcp_link="" udp_link="" vector_link qr_link="" query vector_carrier vector_port
  host="${NOWHERE_PUBLIC_HOST_VALUE:-}"; [[ -n "$host" ]] || die "Public host is empty. Reconfigure the service."
  host="$(format_host_for_url "$host")"; endpoint="$(build_endpoint "$host" "$NOWHERE_TCP_CARRIER_VALUE" "$NOWHERE_TCP_PORT_VALUE" "$NOWHERE_UDP_CARRIER_VALUE" "$NOWHERE_UDP_PORT_VALUE")"; anywhere_endpoint="$(build_endpoint "$host" "$(carrier_without_family "$NOWHERE_TCP_CARRIER_VALUE")" "$NOWHERE_TCP_PORT_VALUE" "$(carrier_without_family "$NOWHERE_UDP_CARRIER_VALUE")" "$NOWHERE_UDP_PORT_VALUE")"; key="$(urlencode "$NOWHERE_KEY_VALUE")"; name="$(urlencode "Nowhere VPS")"
  if is_nw3_version "${NOWHERE_VERSION_VALUE:-$DEFAULT_VERSION}"; then
    if [[ "${NOWHERE_ROLE_VALUE:-portal}" == egress ]]; then
      echo; echo "Role: NW3 Egress"; echo "Release: ${NOWHERE_VERSION_VALUE}"; echo; echo "Egress URL:"; echo "  ${NOWHERE_SERVICE_URL}"; echo; echo "Client command:"; echo "  nowhere '${NOWHERE_SERVICE_URL}'"
      echo; echo "Egress makes an outbound $(egress_transport_label "${NOWHERE_EGRESS_PORTAL_CARRIER_VALUE:-${NOWHERE_EGRESS_PORTAL_UDP_CARRIER_VALUE:-udp}}") connection; no inbound firewall port is required on this VPS."
      return
    fi
    echo; echo "Role: NW3 Portal"; echo "Client output: $(client_label "$NOWHERE_CLIENT_VALUE")"; echo "Release: ${NOWHERE_VERSION_VALUE}"; echo; echo "Portal URL:"; echo "  ${NOWHERE_SERVICE_URL}"; echo
    if [[ "$NOWHERE_CLIENT_VALUE" == vector || "$NOWHERE_CLIENT_VALUE" == both ]]; then
      if [[ "$NOWHERE_TCP_CARRIER_VALUE" != none ]]; then vector_carrier="$NOWHERE_TCP_CARRIER_VALUE"; vector_port="$NOWHERE_TCP_PORT_VALUE"; else vector_carrier="$NOWHERE_UDP_CARRIER_VALUE"; vector_port="$NOWHERE_UDP_PORT_VALUE"; fi
      endpoint="$(build_endpoint "$host" "$vector_carrier" "$vector_port" none "$DEFAULT_PORT")"
      if query="$(build_vector_query)"; then
        vector_link="vector://${key}@${endpoint}?${query}"; echo "Native Vector URL:"; echo "  ${vector_link}"; echo; echo "Client command:"; echo "  nowhere '${vector_link}'"; [[ "$NOWHERE_CLIENT_VALUE" == both ]] && echo
      else
        is_chinese && warn "Native Vector 链接未生成；请先确保 Portal 已启动并能读取证书指纹。" || warn "Native Vector URL was not generated; ensure Portal is running and its certificate fingerprint is available."
      fi
    fi
    if [[ "$NOWHERE_CLIENT_VALUE" == anywhere || "$NOWHERE_CLIENT_VALUE" == both ]]; then
      local morph_query
      morph_query="$(nw3_morph_query "$NOWHERE_VERSION_VALUE" "$NOWHERE_MORPH_VALUE" "${NOWHERE_CIPHER_VALUE:-chacha}")"
      if [[ "$NOWHERE_TCP_CARRIER_VALUE" != none ]]; then
        tcp_link="nowhere://${key}@${host}:${NOWHERE_TCP_PORT_VALUE}?net=tcp&${morph_query}#${name}"
        qr_link="$tcp_link"; echo "Anywhere import link (TLS/TCP):"; echo "  ${tcp_link}"
      fi
      if [[ "$NOWHERE_UDP_CARRIER_VALUE" != none ]]; then
        udp_link="nowhere://${key}@${host}:${NOWHERE_UDP_PORT_VALUE}?net=udp&${morph_query}#${name}"
        [[ -n "$tcp_link" ]] && echo; [[ -n "$qr_link" ]] || qr_link="$udp_link"; echo "Anywhere import link (QUIC/UDP):"; echo "  ${udp_link}"
      fi
      print_qr_code "$qr_link"
    fi
    echo; echo "Firewall reminder:"; [[ "$NOWHERE_TCP_CARRIER_VALUE" == none ]] || echo "  Open TCP ${NOWHERE_TCP_PORT_VALUE}"; [[ "$NOWHERE_UDP_CARRIER_VALUE" == none ]] || echo "  Open UDP ${NOWHERE_UDP_PORT_VALUE}"
    return
  fi
  echo; echo "Client output: $(client_label "$NOWHERE_CLIENT_VALUE")"; echo "Release: ${NOWHERE_VERSION_VALUE}"; echo; echo "Portal URL:"; echo "  ${NOWHERE_PORTAL}"; echo
  if [[ "$NOWHERE_CLIENT_VALUE" == vector || "$NOWHERE_CLIENT_VALUE" == both ]]; then
    if query="$(build_vector_query)"; then
      vector_link="vector://${key}@${endpoint}?${query}"; echo "Native Vector URL:"; echo "  ${vector_link}"; echo; echo "Client command:"; echo "  nowhere '${vector_link}'"; [[ "$NOWHERE_CLIENT_VALUE" == both ]] && echo
    else
      is_chinese && warn "Native Vector 链接未生成；请先确保服务已启动并能读取证书指纹。" || warn "Native Vector URL was not generated; ensure the service is running and its certificate fingerprint is available."
    fi
  fi
  if [[ "$NOWHERE_CLIENT_VALUE" == anywhere || "$NOWHERE_CLIENT_VALUE" == both ]]; then
    base="nowhere://${key}@${anywhere_endpoint}"
    if [[ "$NOWHERE_TCP_CARRIER_VALUE" != none ]]; then tcp_link="${base}?$(build_anywhere_query tcp tcp)#${name}"; qr_link="$tcp_link"; echo "Anywhere import link (TLS/TCP):"; echo "  ${tcp_link}"; fi
    if [[ "$NOWHERE_UDP_CARRIER_VALUE" != none ]]; then udp_link="${base}?$(build_anywhere_query udp udp)#${name}"; [[ -n "$tcp_link" ]] && echo; [[ -n "$qr_link" ]] || qr_link="$udp_link"; echo "Anywhere import link (QUIC/UDP):"; echo "  ${udp_link}"; fi
    print_qr_code "$qr_link"
    if [[ "$endpoint" != "$anywhere_endpoint" ]]; then
      echo "Note: Anywhere links omit tcp4/tcp6/udp4/udp6 suffixes; Native Vector retains them."
    fi
  fi
  echo; echo "Firewall reminder:"; [[ "$NOWHERE_TCP_CARRIER_VALUE" == none ]] || echo "  Open TCP ${NOWHERE_TCP_PORT_VALUE}"; [[ "$NOWHERE_UDP_CARRIER_VALUE" == none ]] || echo "  Open UDP ${NOWHERE_UDP_PORT_VALUE}"
}

local_tls_probe_host() {
  local host="$(strip_brackets "${NOWHERE_LISTEN_HOST_VALUE:-}")" carrier="${1:-${NOWHERE_TCP_CARRIER_VALUE:-tcp}}"
  if [[ -z "$host" || "$host" == '*' || "$host" == 0.0.0.0 || "$host" == :: ]]; then
    [[ "$carrier" == tcp6 || "$carrier" == udp6 ]] && printf '[::1]' || printf '127.0.0.1'
  elif [[ "$host" == *:* ]]; then
    printf '[%s]' "$host"
  else
    printf '%s' "$host"
  fi
}
print_tls_fingerprint_from_logs() {
  recent_service_logs |
    sed -nE 's/.*CERT_SHA256\|([A-Fa-f0-9]{64}).*/\1/p; s/.*TLS certificate SHA-256 fingerprint:[[:space:]]*([A-Fa-f0-9]{64}).*/\1/p; s/.*tls certificate fingerprint:[[:space:]]*([A-Fa-f0-9]{64}).*/\1/p' |
    tail -n 1
}
recent_service_logs() {
  if [[ "$SERVICE_BACKEND" == openrc ]]; then
    tail -n 300 "$(service_log_path)" 2>/dev/null
    return
  fi
  command -v journalctl >/dev/null 2>&1 || return 1
  local invocation journal_args=(-u "$SERVICE_NAME" -n 300 --no-pager)
  invocation="$(systemctl show "$SERVICE_NAME" --property=InvocationID --value 2>/dev/null || true)"
  [[ ! "$invocation" =~ ^[0-9a-fA-F]{32}$ ]] || journal_args+=("_SYSTEMD_INVOCATION_ID=$invocation")
  journalctl "${journal_args[@]}" 2>/dev/null
}
current_local_tls_fingerprint() {
  local fingerprint output host port morph version tcp_carrier key endpoint url alpn=nw2
  service_control is-active >/dev/null 2>&1 || return 1
  morph="${NOWHERE_MORPH_VALUE:-${NOWHERE_MORPH:-$DEFAULT_MORPH}}"
  version="${NOWHERE_VERSION_VALUE:-${NOWHERE_VERSION:-$NW2_LTS_VERSION}}"
  is_nw3_version "$version" && alpn=nw3
  tcp_carrier="${NOWHERE_TCP_CARRIER_VALUE:-${NOWHERE_TCP_CARRIER:-tcp}}"
  port="${NOWHERE_TCP_PORT_VALUE:-${NOWHERE_TCP_PORT:-$DEFAULT_PORT}}"
  if [[ -x "$BIN_PATH" && "$tcp_carrier" != none && -n "${NOWHERE_KEY_VALUE:-${NOWHERE_KEY:-}}" ]]; then
    host="$(local_tls_probe_host "$tcp_carrier")"
    key="$(urlencode "${NOWHERE_KEY_VALUE:-${NOWHERE_KEY:-}}")"
    if is_nw3_version "$version"; then
      url="nowhere://${key}@${host}:${port}?net=tcp&$(nw3_morph_query "$version" "$morph" "${NOWHERE_CIPHER_VALUE:-chacha}")"
    else
      endpoint="$(build_endpoint "$host" "$tcp_carrier" "$port" none "$port")"
      url="nowhere://${key}@${endpoint}?morph=${morph}"
    fi
    output="$("$BIN_PATH" fingerprint "$url" 2>/dev/null || true)"
    fingerprint="${output//:/}"
    fingerprint="$(printf '%s' "$fingerprint" | tr -d '[:space:]' | tr 'A-F' 'a-f')"
    [[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]] && { printf '%s' "$fingerprint"; return; }
  fi
  fingerprint="$(print_tls_fingerprint_from_logs 2>/dev/null || true)"
  fingerprint="${fingerprint//:/}"
  fingerprint="$(printf '%s' "$fingerprint" | tr 'A-F' 'a-f')"
  [[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]] && { printf '%s' "$fingerprint"; return; }
  [[ "$morph" == 0 && "${NOWHERE_TCP_CARRIER:-${NOWHERE_TCP_CARRIER_VALUE:-tcp}}" != none ]] || return 1
  command -v openssl >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 || return 1
  host="$(local_tls_probe_host)"
  output="$(timeout 8 openssl s_client -connect "${host}:${port}" -servername "${NOWHERE_PUBLIC_HOST:-${NOWHERE_PUBLIC_HOST_VALUE:-localhost}}" -alpn "$alpn" -showcerts </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null || true)"
  fingerprint="${output#*=}"
  fingerprint="${fingerprint//:/}"
  fingerprint="$(printf '%s' "$fingerprint" | tr 'A-F' 'a-f')"
  [[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]] || return 1
  printf '%s' "$fingerprint"
}
print_tls_fingerprint() {
  require_root; load_config
  local fingerprint
  if [[ "${NOWHERE_ROLE_VALUE:-portal}" == egress ]]; then
    is_chinese && info "Egress 不提供本地服务端证书。" || info "Egress does not provide a local server certificate."
    return 0
  fi
  fingerprint="$(current_local_tls_fingerprint || true)"
  [[ -n "$fingerprint" ]] && { echo "Certificate SHA-256:"; echo "  ${fingerprint}"; return; }
  warn "Fingerprint unavailable. Check the Logs menu or run this script with the logs command."
}
run_generate_key() {
  require_supported_nowhere
  "$BIN_PATH" generate-key
}
run_remote_fingerprint() {
  require_supported_nowhere
  [[ "$FINGERPRINT_URL" == nowhere://* ]] || die "Usage: sudo bash $SCRIPT_PATH fingerprint nowhere://KEY@HOST:PORT[?QUERY]"
  "$BIN_PATH" fingerprint "$FINGERPRINT_URL"
}
prompt_remote_fingerprint() {
  [[ -t 0 ]] || die "Usage: sudo bash $SCRIPT_PATH fingerprint nowhere://KEY@HOST:PORT[?QUERY]"
  if is_chinese; then read -r -p "输入 nowhere:// 链接: " FINGERPRINT_URL; else read -r -p "Enter a nowhere:// URL: " FINGERPRINT_URL; fi
  run_remote_fingerprint
}

parse_release_metadata() {
  jq -r '.[] | select(.draft != true) | [.tag_name, (.prerelease // false | tostring)] | @tsv'
}
fetch_recent_releases() {
  curl -fsSL --retry 3 --connect-timeout 10 -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/${REPO}/releases?per_page=100" | parse_release_metadata
}
choose_release_version() {
  local preferred="${1:-}" releases=() prereleases=() metadata item pre index choice default_index=0 nw3_count=0 label
  if command -v jq >/dev/null 2>&1; then
    metadata="$(fetch_recent_releases)" || { warn "Cannot fetch release metadata. Retry or use --version with install/update."; return 1; }
  else
    if is_chinese; then warn "未安装 jq，仅显示内置版本；安装 jq 后可查看远程 Release。"
    else warn "jq is not installed; showing bundled versions only. Install jq to list remote releases."; fi
    metadata="$(printf '%s\tfalse\n' "$CIPHER_MIN_VERSION" "$TLS_EGRESS_MIN_VERSION" "$DEFAULT_VERSION")"
    if validate_release_version "$preferred" && is_nw3_version "$preferred" && [[ "$preferred" != "$DEFAULT_VERSION" && "$preferred" != "$TLS_EGRESS_MIN_VERSION" && "$preferred" != "$CIPHER_MIN_VERSION" ]]; then
      metadata+=$'\n'"$(printf '%s\tfalse' "$preferred")"
    fi
  fi
  while IFS=$'\t' read -r item pre; do
    if validate_release_version "$item" && is_nw3_version "$item" && (( nw3_count < 10 )); then
      releases+=("$item"); prereleases+=("${pre:-false}"); nw3_count=$((nw3_count + 1))
      if [[ "${pre:-false}" != true && "$default_index" -eq 0 ]]; then default_index="$nw3_count"; fi
    fi
  done <<<"$metadata"
  releases+=("$NW2_LTS_VERSION")
  prereleases+=(false)
  [[ "$default_index" -ne 0 ]] || default_index="${#releases[@]}"
  if [[ -n "$preferred" ]]; then
    for index in "${!releases[@]}"; do [[ "${releases[$index]}" != "$preferred" ]] || default_index="$((index + 1))"; done
  fi
  echo
  is_chinese && echo "可用的 Nowhere Release（NW2 LTS / NW3）：" || echo "Available Nowhere releases (NW2 LTS / NW3):"
  for index in "${!releases[@]}"; do
    label="${releases[$index]}"
    [[ "${prereleases[$index]}" != true ]] || label="${label} (pre)"
    printf ' %2d) %s\n' "$((index + 1))" "$label"
  done
  is_chinese && echo "  0) 取消" || echo "  0) Cancel"
  while true; do
    if is_chinese; then read -r -p "请选择版本 [${default_index}]: " choice; else read -r -p "Choose a version [${default_index}]: " choice; fi
    choice="${choice:-$default_index}"
    [[ "$choice" == 0 ]] && return 1
    [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= ${#releases[@]} )) && { SELECTED_VERSION="${releases[$((10#$choice - 1))]}"; return; }
    is_chinese && warn "请输入 0..${#releases[@]}。" || warn "Enter 0..${#releases[@]}."
  done
}

install_selected_release() {
  require_root; require_service_manager; load_config; resolve_language
  local jq_offered=1
  offer_jq
  choose_release_version || return 1
  NOWHERE_VERSION="$SELECTED_VERSION"
  install_all
}
install_all() {
  require_root; require_service_manager; load_config
  if [[ -x "$BIN_PATH" && -n "${NOWHERE_VERSION_VALUE:-}" ]]; then
    require_supported_installed_version "$NOWHERE_VERSION_VALUE"
    confirm_protocol_upgrade "$NOWHERE_VERSION_VALUE" "${NOWHERE_VERSION:-$NOWHERE_VERSION_VALUE}" || return 1
  fi
  configure_values || return 1
  confirm_prelude_upgrade "${NOWHERE_VERSION_VALUE:-}" "$NOWHERE_VERSION" || return 1
  if [[ "$NOWHERE_ROLE" == egress ]] && ! is_nw3_version "$NOWHERE_VERSION"; then die "Egress is available only in NW3."; fi
  if [[ "${jq_offered:-0}" -eq 0 ]]; then offer_jq; fi
  if [[ "$NOWHERE_ROLE" == portal && "${NOWHERE_CLIENT:-$DEFAULT_CLIENT}" != vector ]]; then offer_qrencode; fi
  install_binary "$NOWHERE_VERSION"; save_config; write_service; service_control enable
  service_activate
  info "Nowhere service enabled and started."; print_links; print_tls_fingerprint || true
}
install_default() { NOWHERE_CLIENT="${NOWHERE_CLIENT:-$DEFAULT_CLIENT}"; [[ "$ROLE_EXPLICIT" -eq 1 ]] || { NOWHERE_ROLE=portal; ROLE_EXPLICIT=1; }; [[ "$VERSION_EXPLICIT" -eq 1 ]] || NOWHERE_VERSION="$DEFAULT_VERSION"; install_all; }
install_vector() { NOWHERE_CLIENT=vector; [[ "$ROLE_EXPLICIT" -eq 1 ]] || { NOWHERE_ROLE=portal; ROLE_EXPLICIT=1; }; [[ "$VERSION_EXPLICIT" -eq 1 ]] || NOWHERE_VERSION="$DEFAULT_VERSION"; install_all; }
install_egress() { [[ "$VERSION_EXPLICIT" -eq 1 ]] || NOWHERE_VERSION="$DEFAULT_VERSION"; NOWHERE_ROLE=egress; ROLE_EXPLICIT=1; install_all; }
quick_install() { ASSUME_YES=1 install_default; }
configure_all() { require_root; require_service_manager; load_config; NOWHERE_VERSION="${NOWHERE_VERSION_VALUE:-$DEFAULT_VERSION}"; configure_values || return 1; save_config; write_service; if service_control is-enabled >/dev/null 2>&1; then service_activate; fi; print_links; print_tls_fingerprint || true; }
update_saved_version() { sed -i.bak "s/^NOWHERE_VERSION_VALUE=.*/NOWHERE_VERSION_VALUE=$(env_quote "$1")/" "$CONFIG_FILE"; rm -f "${CONFIG_FILE}.bak"; }
update_saved_language() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  if grep -q '^NOWHERE_LANG_VALUE=' "$CONFIG_FILE"; then
    sed -i.bak "s/^NOWHERE_LANG_VALUE=.*/NOWHERE_LANG_VALUE=$(env_quote "$NOWHERE_LANG")/" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
  else
    printf '\nNOWHERE_LANG_VALUE=%s\n' "$(env_quote "$NOWHERE_LANG")" >>"$CONFIG_FILE"
  fi
}
change_language() { NOWHERE_LANG=""; NOWHERE_LANG_VALUE=""; resolve_language; update_saved_language; }
update_all() {
  require_root; require_service_manager; load_config
  [[ -n "${NOWHERE_VERSION_VALUE:-}" ]] || die "No installation config found."
  local current selected preferred current_nw3 selected_nw3
  current="$NOWHERE_VERSION_VALUE"
  require_supported_installed_version "$current"
  if [[ "$VERSION_EXPLICIT" -eq 1 ]]; then
    selected="$NOWHERE_VERSION"
  else
    preferred="$NW2_LTS_VERSION"; is_nw3_version "$current" && preferred=""
    if [[ -z "$preferred" ]] && ! command -v jq >/dev/null 2>&1 && version_at_least "$current" "$CIPHER_MIN_VERSION"; then preferred="$current"; fi
    choose_release_version "$preferred" || return
    selected="$SELECTED_VERSION"
  fi
  require_deployable_version "$selected"
  if [[ "${NOWHERE_MORPH_VALUE:-0}" == 1 && "${NOWHERE_CIPHER_VALUE:-chacha}" == aes ]] && ! supports_morph_cipher "$selected"; then
    die "Switch Morph to chacha before downgrading below v3.4.0."
  fi
  confirm_protocol_upgrade "$current" "$selected" || return
  current_nw3=0; selected_nw3=0
  is_nw3_version "$current" && current_nw3=1
  is_nw3_version "$selected" && selected_nw3=1
  if [[ "$current_nw3" -ne "$selected_nw3" ]]; then
    NOWHERE_VERSION="$selected"
    if [[ "$selected_nw3" -eq 0 && "${NOWHERE_ROLE_VALUE:-portal}" == egress ]]; then
      NOWHERE_PUBLIC_HOST="$(detect_public_host)"
      NOWHERE_TCP_CARRIER=tcp; NOWHERE_TCP_PORT="$DEFAULT_PORT"
      NOWHERE_UDP_CARRIER=udp; NOWHERE_UDP_PORT="$DEFAULT_PORT"
      NOWHERE_ROLE=portal
    fi
    configure_values || return 1
    confirm_prelude_upgrade "$current" "$selected" || return 1
    install_binary "$selected"
    save_config
    write_service
    if service_control is-active >/dev/null 2>&1; then service_control restart; fi
  else
  if [[ "$selected_nw3" -eq 1 ]] && ! supports_tls_egress "$selected"; then
    case "${NOWHERE_ROLE_VALUE:-portal}" in
      egress)
        case "${NOWHERE_EGRESS_PORTAL_CARRIER_VALUE:-${NOWHERE_EGRESS_PORTAL_UDP_CARRIER_VALUE:-udp}}" in
          tcp|tcp4|tcp6) die "Switch Egress to QUIC before downgrading below v3.3.0." ;;
        esac ;;
      portal)
        if [[ "${NOWHERE_OUT_VALUE:-direct}" == egress && "${NOWHERE_UDP_CARRIER_VALUE:-udp}" == none ]]; then
          die "Enable a QUIC/UDP listener before downgrading an Egress Portal below v3.3.0."
        fi ;;
    esac
  fi
  confirm_prelude_upgrade "$current" "$selected" || return 1
  NOWHERE_VERSION="$selected"
  NOWHERE_KEY="${NOWHERE_KEY_VALUE:-}"
  NOWHERE_NEXT="${NOWHERE_NEXT_VALUE:-none}"
  NOWHERE_DIAL="${NOWHERE_DIAL_VALUE:-auto}"
  NOWHERE_DIAL4="${NOWHERE_DIAL4_VALUE:-auto}"
  NOWHERE_DIAL6="${NOWHERE_DIAL6_VALUE:-auto}"
  migrate_shared_key_for_version "$selected" || return
  NOWHERE_LOG_VALUE="${NOWHERE_LOG_VALUE:-${NOWHERE_LOG:-$DEFAULT_LOG}}"
  NOWHERE_VECTOR_LOG_VALUE="${NOWHERE_VECTOR_LOG_VALUE:-${NOWHERE_VECTOR_LOG:-$DEFAULT_LOG}}"
  normalize_removed_event_logs
  persist_removed_event_log_migration
  install_binary "$selected"
  persist_shared_key_migration
  update_saved_version "$selected"
  if service_control is-active >/dev/null 2>&1; then service_control restart; fi
  fi
  info "Nowhere updated to ${selected}."
  print_links
  print_tls_fingerprint || true
}
script_version_from_file() {
  sed -nE 's/^SCRIPT_VERSION="([0-9]+\.[0-9]+\.[0-9]+)"$/\1/p' "$1" | head -n 1
}
check_script_update() (
  # This check only reads remote metadata; it never executes downloaded code.
  [[ -f "$SCRIPT_PATH" ]] && command -v curl >/dev/null 2>&1 || exit 0
  tmp="" remote=""
  tmp="$(mktemp)" || exit 0
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL --connect-timeout 2 --max-time 3 --max-filesize 262144 \
    -o "$tmp" "$SCRIPT_RAW_URL" >/dev/null 2>&1 || exit 0
  remote="$(script_version_from_file "$tmp")"
  [[ "$remote" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || exit 0
  [[ "$remote" != "$SCRIPT_VERSION" ]] && version_at_least "$remote" "$SCRIPT_VERSION" || exit 0
  printf '%s' "$remote"
)
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
  is_chinese && info "请退出并重新运行脚本，以加载新版菜单。Nowhere 服务配置保持不变。" || info "Exit and rerun the script to load the updated menu. Nowhere service configuration is unchanged."
}
open_tui() {
  require_root; [[ -x "$BIN_PATH" ]] || die "Nowhere is not installed."; [[ -t 0 && -t 1 ]] || die "The TUI requires an interactive terminal."
  load_config
  is_nw3_version "${NOWHERE_VERSION_VALUE:-$NW2_LTS_VERSION}" && die "NW3 has no TUI command; use status, logs, or telemetry."
  "$BIN_PATH" tui
}
uninstall_all() {
  require_root; require_service_manager
  if [[ "$SERVICE_BACKEND" == openrc ]]; then
    if service_control is-active; then service_control stop; fi
    if service_control is-enabled; then service_control disable; fi
    rm -f "${CONFIG_DIR}/run" "$(service_log_path)"
  else
    systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  fi
  rm -f "$SERVICE_FILE" "$BIN_PATH"
  if [[ "$SERVICE_BACKEND" == systemd ]]; then systemctl daemon-reload; fi
  warn "Kept ${CONFIG_DIR} to preserve configuration and keys."
}

menu_init_ui() {
  MENU_WIDTH="${COLUMNS:-}"
  if [[ ! "$MENU_WIDTH" =~ ^[0-9]+$ ]]; then MENU_WIDTH="$(tput cols 2>/dev/null || printf 80)"; fi
  [[ "$MENU_WIDTH" =~ ^[0-9]+$ ]] || MENU_WIDTH=80
  (( MENU_WIDTH >= 12 )) || MENU_WIDTH=80
  (( MENU_WIDTH <= 96 )) || MENU_WIDTH=96
  MENU_RESET="" MENU_ACCENT="" MENU_NUMBER="" MENU_TEXT="" MENU_MUTED="" MENU_GOOD="" MENU_WARN="" MENU_BAD="" MENU_CLEAR=""
  MENU_TOP_LEFT=+ MENU_TOP_RIGHT=+ MENU_BOTTOM_LEFT=+ MENU_BOTTOM_RIGHT=+ MENU_HORIZONTAL=- MENU_VERTICAL='|'
  if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
    MENU_TOP_LEFT='╔' MENU_TOP_RIGHT='╗' MENU_BOTTOM_LEFT='╚' MENU_BOTTOM_RIGHT='╝' MENU_HORIZONTAL='═' MENU_VERTICAL='║'
    [[ ! -t 0 ]] || MENU_CLEAR=$'\033[2J\033[H'
    if [[ ! ${NO_COLOR+x} ]]; then
      MENU_RESET=$'\033[0m' MENU_ACCENT=$'\033[36m' MENU_NUMBER=$'\033[32m'
      MENU_TEXT=$'\033[1;37m' MENU_MUTED=$'\033[90m' MENU_GOOD=$'\033[32m'
      MENU_WARN=$'\033[33m' MENU_BAD=$'\033[31m'
    fi
  fi
}

# Count UTF-8 display cells without depending on the VPS locale.
menu_text_width() {
  local LC_ALL=C value="$1" index=0 byte width=0 step
  while (( index < ${#value} )); do
    printf -v byte '%d' "'${value:index:1}"
    byte=$((byte & 255))
    step=1
    if (( byte >= 240 )); then step=4; width=$((width + 2))
    elif (( byte >= 224 )); then step=3; width=$((width + 2))
    elif (( byte >= 192 )); then step=2; width=$((width + 1))
    else width=$((width + 1)); fi
    index=$((index + step))
  done
  printf '%s' "$width"
}

menu_fit_text() {
  local LC_ALL=C value="${1//[[:cntrl:]]/ }" limit="$2" width index=0 byte step cells used=0 result="" suffix=""
  width="$(menu_text_width "$value")"
  if (( width > limit )); then suffix="..."; limit=$((limit - 3)); fi
  (( limit >= 0 )) || limit=0
  while (( index < ${#value} )); do
    printf -v byte '%d' "'${value:index:1}"
    byte=$((byte & 255))
    step=1; cells=1
    if (( byte >= 240 )); then step=4; cells=2
    elif (( byte >= 224 )); then step=3; cells=2
    elif (( byte >= 192 )); then step=2; fi
    (( used + cells <= limit )) || break
    result="${result}${value:index:step}"
    used=$((used + cells)); index=$((index + step))
  done
  printf '%s%*s%s' "$result" "$((limit - used))" "" "$suffix"
}

menu_header_rule() {
  local left="$1" right="$2" index
  printf '%s%s' "$MENU_ACCENT" "$left"
  for ((index=0; index < MENU_WIDTH - 2; index++)); do printf '%s' "$MENU_HORIZONTAL"; done
  printf '%s%s\n' "$right" "$MENU_RESET"
}
menu_header_line() {
  printf '%s%s %s%s%s %s%s\n' "$MENU_ACCENT" "$MENU_VERTICAL" "${2:-$MENU_MUTED}" \
    "$(menu_fit_text "$1" "$((MENU_WIDTH - 4))")" "$MENU_ACCENT" "$MENU_VERTICAL" "$MENU_RESET"
}
menu_section() {
  local label="$1"; is_chinese && label="$2"
  printf '\n%s  %s%s\n' "$MENU_ACCENT" "$(menu_fit_text "$label" "$((MENU_WIDTH - 2))")" "$MENU_RESET"
}
menu_entry() {
  local number="$1" label="$2" description="$4"
  if is_chinese; then label="$3"; description="$5"; fi
  printf ' %s%2s.%s %s' "$MENU_NUMBER" "$number" "$MENU_RESET" "$MENU_TEXT"
  if (( MENU_WIDTH >= 76 )); then
    printf '%s%s  %s%s%s\n' "$(menu_fit_text "$label" 30)" "$MENU_RESET" "$MENU_MUTED" \
      "$(menu_fit_text "$description" "$((MENU_WIDTH - 37))")" "$MENU_RESET"
  else
    printf '%s%s\n' "$(menu_fit_text "$label" "$((MENU_WIDTH - 5))")" "$MENU_RESET"
  fi
}

menu_render() {
  local state="" status status_color="$MENU_WARN" role="${NOWHERE_ROLE_VALUE:-portal}" role_label=Portal host ports="" output tls title
  if [[ ! -x "$BIN_PATH" ]]; then
    status="Not installed"; is_chinese && status="未安装"
  else
    state="$(service_state 2>/dev/null || true)"
    case "$state" in
      active) status="Running"; is_chinese && status="运行中"; status_color="$MENU_GOOD" ;;
      failed) status="Failed"; is_chinese && status="启动失败"; status_color="$MENU_BAD" ;;
      inactive) status="Stopped"; is_chinese && status="已停止" ;;
      *) status="Unavailable"; is_chinese && status="状态不可用" ;;
    esac
  fi
  [[ "$role" != egress ]] || role_label=Egress
  printf '%s\n' "$MENU_CLEAR"
  menu_header_rule "$MENU_TOP_LEFT" "$MENU_TOP_RIGHT"
  title="Nowhere VPS Manager"; is_chinese && title="Nowhere VPS 管理脚本"
  menu_header_line "$title" "$MENU_TEXT"
  menu_header_line "${status}  |  ${role_label}  |  ${NOWHERE_VERSION_VALUE:--}" "$status_color"
  if [[ "$role" == egress ]]; then
    host="${NOWHERE_EGRESS_PORTAL_HOST_VALUE:--}"
    local egress_carrier="${NOWHERE_EGRESS_PORTAL_CARRIER_VALUE:-${NOWHERE_EGRESS_PORTAL_UDP_CARRIER_VALUE:-udp}}"
    ports="${egress_carrier}:${NOWHERE_EGRESS_PORTAL_PORT_VALUE:-${NOWHERE_EGRESS_PORTAL_UDP_PORT_VALUE:-$DEFAULT_PORT}}"
    menu_header_line "Portal: ${host}  ${ports}"
    if is_chinese; then menu_header_line "出口模式：Egress / 主动 $(egress_transport_label "$egress_carrier") 连接"
    else menu_header_line "Exit: Egress / outbound $(egress_transport_label "$egress_carrier")"; fi
  else
    host="${NOWHERE_PUBLIC_HOST_VALUE:--}"
    [[ "${NOWHERE_TCP_CARRIER_VALUE:-none}" == none ]] || ports="TCP:${NOWHERE_TCP_PORT_VALUE:-$DEFAULT_PORT}"
    [[ "${NOWHERE_UDP_CARRIER_VALUE:-none}" == none ]] || ports="${ports:+${ports}  }UDP:${NOWHERE_UDP_PORT_VALUE:-$DEFAULT_PORT}"
    output="${NOWHERE_OUT_VALUE:-direct}"
    if ! is_nw3_version "${NOWHERE_VERSION_VALUE:-$DEFAULT_VERSION}"; then
      if [[ "${NOWHERE_NEXT_VALUE:-none}" != none ]]; then output=next
      elif [[ "${NOWHERE_SOCKS_VALUE:-none}" != none ]]; then output=socks; fi
    fi
    tls="Self-signed"; is_chinese && tls="自签证书"
    [[ "${NOWHERE_TLS_VALUE:-1}" != 2 ]] || tls=PEM
    if is_chinese; then
      menu_header_line "入口：${host}  ${ports}"
      menu_header_line "出口：${output}  |  TLS: ${tls}  |  $(client_label "${NOWHERE_CLIENT_VALUE:-$DEFAULT_CLIENT}")"
    else
      menu_header_line "Host: ${host}  ${ports}"
      menu_header_line "Exit: ${output}  |  TLS: ${tls}  |  $(client_label "${NOWHERE_CLIENT_VALUE:-$DEFAULT_CLIENT}")"
    fi
  fi
  if [[ -n "$SCRIPT_UPDATE_AVAILABLE_VERSION" ]]; then
    if [[ "$(script_version_from_file "$SCRIPT_PATH")" == "$SCRIPT_UPDATE_AVAILABLE_VERSION" ]]; then
      if is_chinese; then menu_header_line "脚本新版已下载，请退出并重新运行" "$MENU_WARN"
      else menu_header_line "Script downloaded. Exit and rerun to load it." "$MENU_WARN"; fi
    else
      if is_chinese; then menu_header_line "脚本有更新：${SCRIPT_UPDATE_AVAILABLE_VERSION}，选 22 更新" "$MENU_WARN"
      else menu_header_line "Script update: ${SCRIPT_UPDATE_AVAILABLE_VERSION}. Choose 22." "$MENU_WARN"; fi
    fi
  fi
  menu_header_rule "$MENU_BOTTOM_LEFT" "$MENU_BOTTOM_RIGHT"
  menu_section "Deployment & configuration" "部署与配置"
  menu_entry 1 "Install Portal (Anywhere)" "安装/重装（Anywhere）" "Anywhere import links" "生成 Anywhere 导入链接"
  menu_entry 2 "Install Portal (Native Vector)" "安装/重装（原生 Vector）" "Native client configuration" "生成原生客户端配置"
  menu_entry 3 "Install Egress" "安装/重装（Egress）" "Remote exit through Portal" "连接 Portal，提供远程出口"
  menu_entry 4 "Quick default install" "快速默认安装" "Anywhere / default settings" "Anywhere / 全部使用默认值"
  menu_entry 5 "Reconfigure" "修改配置" "Ports, TLS, Morph and exit" "端口、证书、Morph 和出口"
  menu_entry 6 "Install a selected release" "指定 Release 安装" "Choose a release" "查看并选择发行版本"
  menu_entry 7 "Update Nowhere binary" "更新 Nowhere 二进制" "Update or migrate protocol" "更新版本或切换协议"
  menu_section "Service management" "服务管理"
  menu_entry 8 "Start service" "启动服务" "Start the saved deployment" "启动已保存的服务"
  menu_entry 9 "Stop service" "停止服务" "Stop the running service" "关停当前服务"
  menu_entry 10 "Restart service" "重启服务" "Reload the saved configuration" "重新加载已保存配置"
  menu_entry 11 "Instance status" "查看 Nowhere 实例状态" "Traffic and active flows" "流量统计与活跃连接"
  menu_entry 12 "Probe TCP connectivity" "测试 TCP 连通性" "Test a target through Portal" "通过 Portal 测试目标连接"
  menu_entry 13 "Service status" "查看服务状态" "Process status" "进程状态"
  menu_entry 14 "Terminal UI (NW2 only)" "打开终端界面（仅 NW2）" "Interactive NW2 dashboard" "NW2 原生交互面板"
  menu_entry 15 "Follow logs" "查看实时日志" "Live service output" "实时查看服务输出"
  menu_section "Links & maintenance" "链接与维护"
  menu_entry 16 "Client links / QR code" "打印客户端链接 / 二维码" "Share or import the node" "分享或导入当前节点"
  menu_entry 17 "Certificate SHA-256" "查看证书 SHA-256" "Current Portal fingerprint" "查询 Portal 证书指纹"
  menu_entry 18 "Generate shared key" "生成共享密钥" "Generate a key without applying it" "生成新密钥，不自动替换配置"
  menu_entry 19 "Inspect remote fingerprint" "查询远端证书指纹" "Inspect a remote Portal" "查询远端 Portal 的证书"
  menu_entry 20 "Uninstall service" "卸载服务" "Keep saved configuration and keys" "保留已保存的配置与密钥"
  menu_section "Script settings" "脚本设置"
  menu_entry 21 "Switch language" "切换语言" "English / 简体中文" "English / 简体中文"
  menu_entry 22 "Update deployment script" "更新部署脚本" "Download the latest script" "下载最新部署脚本"
  printf '\n'
  menu_entry q "Exit" "退出" "Also accepts 0" "也可输入 0"
  printf '\n'
}

menu_dispatch() {
  case "$1" in
    1) install_default ;; 2) install_vector ;; 3) install_egress ;; 4) quick_install ;;
    5) configure_all ;; 6) install_selected_release ;;
    7) update_all ;; 8) service_cmd start ;; 9) service_cmd stop ;; 10) service_cmd restart ;;
    11) run_nowhere_status ;; 12) run_probe ;; 13) service_cmd status ;; 14) open_tui ;;
    15) service_logs ;; 16) print_links ;; 17) print_tls_fingerprint ;;
    18) run_generate_key ;; 19) prompt_remote_fingerprint ;; 20) uninstall_all ;;
    22) update_script ;;
    *) is_chinese && warn "未知选项: $1" || warn "Unknown option: $1" ;;
  esac
}

menu() {
  require_root; require_service_manager
  load_config; resolve_language; update_saved_language
  local choice prompt
  if [[ -t 0 && -t 1 ]]; then SCRIPT_UPDATE_AVAILABLE_VERSION="$(check_script_update)"; fi
  while true; do
    load_config; menu_init_ui; menu_render
    prompt="? Choose: "; is_chinese && prompt="? 请选择: "
    printf '%s%s%s' "$MENU_ACCENT" "$prompt" "$MENU_RESET"
    read -r choice || return 0
    case "$choice" in
      0|q|Q) return 0 ;;
      21) change_language ;;
      *) set +e; (set -e; menu_dispatch "$choice"); set -e ;;
    esac
    if [[ -t 0 ]]; then
      prompt="Press Enter to return to the menu..."; is_chinese && prompt="按回车返回主菜单..."
      printf '\n%s%s%s' "$MENU_MUTED" "$prompt" "$MENU_RESET"
      read -r choice || return 0
    fi
  done
}

case "$ACTION" in
  install|install-anywhere|anywhere) install_default ;;
  install-vector|vector) install_vector ;;
  install-egress|egress) install_egress ;;
  configure|config) configure_all ;;
  update) update_all ;;
  update-script|script-update|self-update) update_script ;;
  versions|version|releases|release) install_selected_release ;;
  start|stop|restart|status) service_cmd "$ACTION" ;;
  telemetry|instances|runtime-status) run_nowhere_status ;;
  probe) run_probe "$PROBE_TARGET" ;;
  tui|dashboard|monitor) open_tui ;;
  logs|log) service_logs ;;
  link|links) print_links ;;
  fingerprint) if [[ -n "$FINGERPRINT_URL" ]]; then run_remote_fingerprint; else print_tls_fingerprint; fi ;;
  sha256|sha-256) print_tls_fingerprint ;;
  generate-key) run_generate_key ;;
  uninstall|remove) uninstall_all ;;
  menu) menu ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
