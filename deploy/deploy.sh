#!/usr/bin/env bash
# ============================================================
# NasAnySim one-click deploy
# Usage: bash deploy.sh <domain> [email] [--dry-run]
#   bash deploy.sh nasany.example.com you@example.com
#   bash deploy.sh nasany.example.com --dry-run  (config only)
# ============================================================
set -euo pipefail

DOMAIN="${1:-}"
EMAIL="${2:-}"
DRY_RUN=0
if [[ "${3:-}" == "--dry-run" || "${2:-}" == "--dry-run" ]]; then DRY_RUN=1; EMAIL=""; fi
if [[ -z "$DOMAIN" ]]; then
  echo "ERROR: usage: bash deploy.sh <domain> [email] [--dry-run]"
  echo "  example: bash deploy.sh nasany.example.com you@example.com"
  exit 1
fi

# Check docker
if [[ "$DRY_RUN" -eq 0 ]] && ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Install first: https://docs.docker.com/engine/install/"
  exit 1
fi

# Module serial port (override here if different)
TTY="/dev/ttyUSB2"
if [[ ! -e "$TTY" ]]; then
  echo "WARN: $TTY (4G module serial) not found. Edit TTY in this script if different."
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
TURN_IP="$(ip -4 addr show 2>/dev/null | grep -oP 'inet \K[0-9.]+' | grep -v '^127\.' | head -1)"
TURN_EXTERNAL="${TURN_IP:-127.0.0.1}"
cat > coturn/turnserver.conf <<EOF
realm=${DOMAIN}
server-name=${DOMAIN}
listening-ip=${TURN_IP:-0.0.0.0}
listening-port=3478
fingerprint
use-auth-secret
static-auth-secret=${TURN_SECRET}
min-port=49160
max-port=49167
no-dtls
no-tls
EOF
echo "OK: coturn/turnserver.conf"

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
