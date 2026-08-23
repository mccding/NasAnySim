#!/usr/bin/env bash
# ============================================================
# NasAnySim one-click deploy
# Usage: bash deploy.sh [domain] [email] [serial-port] [--dry-run]
#   bash deploy.sh nasany.example.com you@example.com
#   bash deploy.sh nasany.example.com you@example.com /dev/ttyACM0
#   bash deploy.sh nasany.example.com --dry-run  (config only)
#
# Configurable via environment variables (override CLI args):
#   NASANY_DOMAIN   your public domain (also used as TURN realm)
#   NASANY_EMAIL    email for Let's Encrypt auto cert
#   NASANY_TTY      module serial port (default /dev/ttyUSB2)
#   NASANY_PUBLIC_IP  your public IP (auto-detected via DDNS if unset)
# ============================================================
set -euo pipefail

# Load optional .env (for Docker/Compose-style configuration)
# .env can set NASANY_DOMAIN, NASANY_EMAIL, NASANY_TTY
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

DOMAIN="${1:-${NASANY_DOMAIN:-}}"
EMAIL="${2:-${NASANY_EMAIL:-}}"
TTY_ARG="${3:-}"
DRY_RUN=0
if [[ "$DOMAIN" == "--dry-run" ]]; then DOMAIN="${NASANY_DOMAIN:-}"; DRY_RUN=1; fi
if [[ "${4:-}" == "--dry-run" || "${3:-}" == "--dry-run" ]]; then DRY_RUN=1; EMAIL=""; fi
if [[ -z "$DOMAIN" ]]; then
  echo "ERROR: usage: bash deploy.sh <domain> [email] [--dry-run]"
  echo "  example: bash deploy.sh nasany.example.com you@example.com"
  echo "  or set NASANY_DOMAIN env var"
  exit 1
fi

# Check docker
if [[ "$DRY_RUN" -eq 0 ]] && ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Install first: https://docs.docker.com/engine/install/"
  exit 1
fi

# Module serial port: 3rd CLI arg > NASANY_TTY env > default /dev/ttyUSB2
TTY="${TTY_ARG:-${NASANY_TTY:-/dev/ttyUSB2}}"
if [[ ! -e "$TTY" ]]; then
  echo "WARN: $TTY (4G module serial) not found. Pass the module serial as the 3rd argument or set NASANY_TTY."
fi

# TURN secret
if [[ ! -f turn-secret ]]; then
  echo "GEN: turn-secret"
  openssl rand -base64 32 > turn-secret
  chmod 600 turn-secret
fi
TURN_SECRET="$(tr -d '\n' < turn-secret)"

# TURN config (coturn.conf)
mkdir -p coturn
TURN_IP="$(ip -4 addr show 2>/dev/null | grep -E 'inet ' | awk '{print $2}' | cut -d/ -f1 | grep -v '^127\.' | head -1 || true)"
# Public IP for the TURN relay candidate (external-ip). Prefer NASANY_PUBLIC_IP
# (user-provided), else resolve from the domain (DDNS), else fall back to the LAN IP.
if [[ -n "${NASANY_PUBLIC_IP:-}" ]]; then
  PUBLIC_IP="$NASANY_PUBLIC_IP"
elif command -v getent >/dev/null 2>&1 && getent hosts "$DOMAIN" >/dev/null 2>&1; then
  PUBLIC_IP="$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1)"
else
  PUBLIC_IP=""
fi
PUBLIC_IP="${PUBLIC_IP:-$TURN_IP}"
# Optional TLS: if the user supplies fullchain.pem + privkey.pem in ./coturn,
# enable the TLS listener on 5349 (needs UDP+TCP 5349 port-forwarded).
TLS_BLOCK=""
if [[ -f coturn/fullchain.pem && -f coturn/privkey.pem ]]; then
  TLS_BLOCK="tls-listening-port=5349
cert=/etc/coturn/fullchain.pem
pkey=/etc/coturn/privkey.pem"
  echo "NOTE: TLS 5349 enabled (found ./coturn/fullchain.pem + privkey.pem)"
else
  echo "NOTE: no TLS certs in ./coturn — TURN over UDP 3478 only (no-tls)."
fi
cat > coturn/turnserver.conf <<EOF
realm=${DOMAIN}
server-name=${DOMAIN}
listening-ip=${TURN_IP:-0.0.0.0}
relay-ip=${TURN_IP:-0.0.0.0}
external-ip=${PUBLIC_IP}/${TURN_IP}
listening-port=3478
${TLS_BLOCK}
no-dtls
min-port=49160
max-port=49167
fingerprint
use-auth-secret
static-auth-secret=${TURN_SECRET}
secure-stun
user-quota=4
total-quota=8
max-bps=256000
bps-capacity=2000000
stale-nonce=600
max-allocate-lifetime=600
channel-lifetime=600
permission-lifetime=300
allocation-default-address-family=ipv4
no-multicast-peers
no-rfc5780
no-tcp-relay
no-cli
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=224.0.0.0-255.255.255.255
log-file=stdout
simple-log
EOF
echo "OK: coturn/turnserver.conf (external-ip=${PUBLIC_IP})"

# Session secret
mkdir -p data/auth
if [[ ! -f data/auth/session-secret ]]; then
  echo "GEN: data/auth/session-secret"
  openssl rand -base64 48 > data/auth/session-secret
  chmod 600 data/auth/session-secret
fi

echo "DOMAIN: $DOMAIN"
if [[ -n "$EMAIL" ]]; then TLS_LINE="tls $EMAIL"; else TLS_LINE="tls internal"; fi

# Caddyfile
mkdir -p caddy
cat > caddy/Caddyfile <<EOF
https://${DOMAIN}:7577 {
    ${TLS_LINE}
    handle /remote/auth/* {
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }
    handle /remote/*.png { reverse_proxy 127.0.0.1:7578 { header_up Host localhost } }
    handle /remote/*.svg { reverse_proxy 127.0.0.1:7578 { header_up Host localhost } }
    handle /remote/manifest.webmanifest { reverse_proxy 127.0.0.1:7578 { header_up Host localhost } }
    handle {
        forward_auth 127.0.0.1:7578 {
            uri /api/remote/v1/auth/check
            header_up Host localhost
        }
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }
}
EOF
echo "OK: caddy/Caddyfile"

# docker-compose.yaml
# If another reverse proxy already listens on 7577 (or any public HTTPS port),
# do NOT start the bundled caddy container — let the user's proxy handle it.
# The script still writes ./caddy/Caddyfile so the user can copy the site block.
CADDY_START="true"
CADDY_PROFILE='["default"]'
if command -v ss >/dev/null 2>&1 && ss -tln 2>/dev/null | grep -qE ':(7577)\b'; then
  CADDY_START="false"
  CADDY_PROFILE='["optional"]'
  echo "NOTE: port 7577 already in use (existing reverse proxy detected)."
  echo "      Skipping the bundled caddy container. Add the site block from"
  echo "      ./caddy/Caddyfile to your own proxy, or forward 7577 -> 127.0.0.1:7578."
elif command -v netstat >/dev/null 2>&1 && netstat -tln 2>/dev/null | grep -qE ':(7577)\b'; then
  CADDY_START="false"
  CADDY_PROFILE='["optional"]'
  echo "NOTE: port 7577 already in use (existing reverse proxy detected)."
  echo "      Skipping the bundled caddy container. Add the site block from"
  echo "      ./caddy/Caddyfile to your own proxy, or forward 7577 -> 127.0.0.1:7578."
fi
cat > docker-compose.yaml <<EOF
services:
  nasany-sms:
    image: mccdingding/nasany-sms:latest
    container_name: nasany-sms
    restart: unless-stopped
    network_mode: host
    devices:
      - ${TTY}:${TTY}
      - /dev/snd:/dev/snd
    volumes:
      - ./data:/var/lib/maccellular
      - ./turn-secret:/run/secrets/turn-secret:ro
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    command:
      - -listen
      - 127.0.0.1:7576
      - -port
      - ${TTY}
      - -phone-relay-runtime
      - -sms-store
      - /var/lib/maccellular
      - -call-history-store
      - /var/lib/maccellular/call-history.json
      - -remote-listen
      - 127.0.0.1:7578
      - -remote-host
      - localhost
      - -remote-control
      - -remote-allow-loopback
      - -remote-recordings-dir
      - /var/lib/maccellular/call-recordings
      - -remote-cookie-auth
      - -remote-cookie-auth-password-hash-file
      - /var/lib/maccellular/auth/password-hash
      - -remote-cookie-auth-username-file
      - /var/lib/maccellular/auth/username
      - -remote-cookie-auth-initialized-file
      - /var/lib/maccellular/auth/initialized
      - -remote-cookie-auth-secret-file
      - /var/lib/maccellular/auth/session-secret
      - -remote-media-turn-host
      - ${DOMAIN}
      - -remote-media-turn-secret-file
      - /run/secrets/turn-secret
      - -remote-media-turn-udp-port
      - "3478"
      - -remote-incoming-answer
      - -remote-rescue-hangup
      - -remote-push
      - -remote-push-vapid-private-key-file
      - /var/lib/maccellular/vapid-private-key
      - -remote-push-vapid-subject
      - mailto:${EMAIL:-admin@${DOMAIN}}
      - -remote-push-subscriptions-file
      - /var/lib/maccellular/push/subscriptions.json
      - -web-console

  nasany-turn:
    image: coturn/coturn:latest
    container_name: nasany-turn
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./coturn:/etc/coturn:ro
    command: ["-c", "/etc/coturn/turnserver.conf"]
    cap_add:
      - NET_BIND_SERVICE

  caddy:
    image: caddy:2-alpine
    container_name: nasany-caddy
    restart: unless-stopped
    network_mode: host
    profiles: ${CADDY_PROFILE:-["default"]}
    volumes:
      - ./caddy:/etc/caddy
      - caddy_data:/data
    command: caddy run --config /etc/caddy/Caddyfile

volumes:
  caddy_data:
EOF
echo "OK: docker-compose.yaml"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "=============================================="
  echo "Config generated (dry-run, not started)."
  echo "Next: bash deploy.sh ${DOMAIN} ${EMAIL}"
  echo "=============================================="
  exit 0
fi

echo ""
echo "Starting..."
docker compose up -d
echo ""
echo "=============================================="
echo "Done! Access: https://${DOMAIN}:7577/remote/"
echo "Default login: admin / admin"
echo "IMPORTANT: change the password after first login!"
echo "=============================================="
