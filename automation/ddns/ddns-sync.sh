#!/usr/bin/env bash
set -euo pipefail

# DDNS sync for home labs.
# Reads configuration from environment variables or a .env file.
# Intended for IONOS DynDNS update URLs but works with any provider URL.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
fi

: "${DDNS_HOSTNAME:?DDNS_HOSTNAME is required}"
: "${DDNS_UPDATE_URL:?DDNS_UPDATE_URL is required}"

LOCK_FILE="${LOCK_FILE:-/tmp/ddns-sync.lock}"
LOG_FILE="${LOG_FILE:-/tmp/ddns-sync.log}"
DNS_RESOLVER="${DNS_RESOLVER:-1.1.1.1}"

mkdir -p "$(dirname "$LOG_FILE")"

ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(ts)] $*" | tee -a "$LOG_FILE"
}

get_public_ip() {
  local ip
  for endpoint in \
    "https://ifconfig.me" \
    "https://api.ipify.org" \
    "https://ipv4.icanhazip.com"
  do
    ip="$(curl -4 -fsS --max-time 8 "$endpoint" | tr -d '[:space:]' || true)"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      echo "$ip"
      return 0
    fi
  done
  return 1
}

get_dns_ip() {
  dig +short A "$DDNS_HOSTNAME" "@$DNS_RESOLVER" | head -n1 | tr -d '[:space:]'
}

build_update_url() {
  local url="$DDNS_UPDATE_URL"
  url="${url//\{ip\}/$1}"
  url="${url//\{host\}/$DDNS_HOSTNAME}"
  echo "$url"
}

send_alert() {
  local message="$1"
  if [[ -n "${ALERT_WEBHOOK_URL:-}" ]]; then
    curl -fsS -X POST -H 'Content-Type: application/json' \
      -d "{\"text\":\"$message\"}" "$ALERT_WEBHOOK_URL" >/dev/null || true
  fi
}

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  log "Another ddns-sync instance is already running."
  exit 0
fi

PUBLIC_IP="$(get_public_ip || true)"
if [[ -z "$PUBLIC_IP" ]]; then
  log "ERROR: Could not detect public IPv4 address."
  send_alert "DDNS sync failed: could not detect public IPv4"
  exit 1
fi

DNS_IP="$(get_dns_ip || true)"
if [[ "$DNS_IP" == "$PUBLIC_IP" ]]; then
  log "OK: DNS is current for $DDNS_HOSTNAME ($PUBLIC_IP)."
  exit 0
fi

UPDATE_URL="$(build_update_url "$PUBLIC_IP")"
log "INFO: DNS drift detected for $DDNS_HOSTNAME (dns=$DNS_IP public=$PUBLIC_IP). Triggering update."

HTTP_CODE="$(curl -4 -sS -o /tmp/ddns-sync-response.txt -w '%{http_code}' --max-time 15 "$UPDATE_URL" || true)"
BODY="$(cat /tmp/ddns-sync-response.txt 2>/dev/null || true)"

if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
  log "SUCCESS: Provider update accepted (HTTP $HTTP_CODE)."
  log "Provider response: $BODY"
  exit 0
fi

log "ERROR: Provider update failed (HTTP $HTTP_CODE)."
log "Provider response: $BODY"
send_alert "DDNS sync failed for $DDNS_HOSTNAME (HTTP $HTTP_CODE)"
exit 1
