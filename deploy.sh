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
if [[ "$TTY_ARG" == "--dry-run" ]]; then TTY_ARG=""; fi
DRY_RUN=0
# --dry-run may appear as $1 (no domain, .env only), $2 (domain, no email),
# $3 (domain + email) or $4 (domain + email + tty).
if [[ "$DOMAIN" == "--dry-run" || "$EMAIL" == "--dry-run" || "${3:-}" == "--dry-run" || "${4:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  if [[ "$DOMAIN" == "--dry-run" ]]; then DOMAIN="${NASANY_DOMAIN:-}"; fi
  if [[ "$EMAIL" == "--dry-run" ]]; then EMAIL="${NASANY_EMAIL:-}"; fi
fi
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

# VAPID private key for Web Push (-remote-push). Without it the gateway refuses
# to start (log.Fatal), so generate a P-256 key on first run.
# Format: 43-char base64url (no padding), P-256 private key scalar.
if [[ ! -f data/vapid-private-key ]]; then
  echo "GEN: data/vapid-private-key"
  openssl ecparam -genkey -name prime256v1 -noout 2>/dev/null \
    | openssl ec -outform DER 2>/dev/null \
    | tail -c 32 \
    | openssl base64 -A 2>/dev/null \
    | tr '+/' '-_' | tr -d '=' > data/vapid-private-key
  chmod 600 data/vapid-private-key
fi

echo "DOMAIN: $DOMAIN"
# TLS strategy, most reliable first:
#   1) NASANY_DUCKDNS_TOKEN set -> auto-issue a real cert via acme.sh DNS-01
#      (works on home broadband where port 80 is blocked; DuckDNS only).
#   2) User-supplied certs in ./caddy/{fullchain,privkey}.pem -> use them.
#   3) EMAIL given -> Let's Encrypt HTTP-01 (needs port 80 free + forwarded).
#   4) Otherwise -> self-signed `tls internal` (works out of the box).
if [[ -n "${NASANY_DUCKDNS_TOKEN:-}" ]]; then
  echo "TLS: DuckDNS token present — issuing a real cert via acme.sh DNS-01..."
  if command -v acme.sh >/dev/null 2>&1 || [[ -f ~/.acme.sh/acme.sh ]]; then
    ACME="$([ -f ~/.acme.sh/acme.sh ] && echo ~/.acme.sh/acme.sh || command -v acme.sh)"
    mkdir -p caddy
    export DuckDNS_Token="$NASANY_DUCKDNS_TOKEN"
    "$ACME" --issue --dns dns_duckdns -d "$DOMAIN" --keylength ec-256 --force 2>&1 | tail -3 || echo "acme.sh issue failed — falling back to user certs/internal"
    if [[ -f ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer && -f ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key ]]; then
      cp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer caddy/fullchain.pem
      cp ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key caddy/privkey.pem
      chmod 600 caddy/privkey.pem
      TLS_LINE="tls /etc/caddy/fullchain.pem /etc/caddy/privkey.pem"
      echo "TLS: real cert issued (DuckDNS DNS-01) -> ./caddy/fullchain.pem"
    else
      echo "TLS: acme.sh did not produce a cert — falling through"
    fi
  else
    echo "TLS: acme.sh not found — install it or provide certs; falling through"
  fi
fi
if [[ -z "${TLS_LINE:-}" && -f caddy/fullchain.pem && -f caddy/privkey.pem ]]; then
  TLS_LINE="tls /etc/caddy/fullchain.pem /etc/caddy/privkey.pem"
  echo "TLS: using user-provided certs ./caddy/fullchain.pem + privkey.pem"
elif [[ -z "${TLS_LINE:-}" && -n "$EMAIL" ]]; then
  TLS_LINE="tls $EMAIL"
  echo "TLS: Let's Encrypt via $EMAIL (requires port 80 free & forwarded to this host)"
elif [[ -z "${TLS_LINE:-}" ]]; then
  TLS_LINE="tls internal"
  echo "TLS: self-signed (tls internal) — add ./caddy/fullchain.pem + privkey.pem and re-run for real certs"
fi

# Caddyfile
mkdir -p caddy
cat > caddy/Caddyfile <<EOF
{
    admin off
}

https://${DOMAIN}:7577 {
    ${TLS_LINE}
    handle /remote/auth/* {
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }
    handle /remote/*.png {
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }
    handle /remote/*.svg {
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }
    handle /remote/manifest.webmanifest {
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }
    handle {
        forward_auth 127.0.0.1:7578 {
            uri /api/remote/v1/auth/check
            header_up Host localhost
        }
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }
}
EOF
echo "OK: caddy/Caddyfile"

# Caddy is ALWAYS part of the default deploy so a fresh user gets HTTPS + auth
# out of the box. If port 7577 is already occupied we warn, but we do NOT
# silently drop caddy — the container will try to bind and fail; the warning
# explains how to integrate with an existing proxy. Set NASANY_SKIP_CADDY=1 to
# explicitly exclude it.
CADDY_START="true"
CADDY_PROFILE='["default"]'
if [[ "${NASANY_SKIP_CADDY:-0}" == "1" ]]; then
  CADDY_START="false"
  CADDY_PROFILE='["optional"]'
  echo "NOTE: NASANY_SKIP_CADDY=1 — skipping the bundled caddy container."
elif command -v ss >/dev/null 2>&1 && ss -tln 2>/dev/null | grep -qE ':(7577)\b'; then
  echo "WARN: port 7577 already in use. The bundled caddy container may not be"
  echo "      able to bind. If you run your own reverse proxy, integrate the"
  echo "      site block from ./caddy/Caddyfile and set NASANY_SKIP_CADDY=1."
elif command -v netstat >/dev/null 2>&1 && netstat -tln 2>/dev/null | grep -qE ':(7577)\b'; then
  echo "WARN: port 7577 already in use. The bundled caddy container may not be"
  echo "      able to bind. If you run your own reverse proxy, integrate the"
  echo "      site block from ./caddy/Caddyfile and set NASANY_SKIP_CADDY=1."
fi
# Detect host architecture → choose the matching image tag.
# arm64 (most NAS) → :latest (arm64); x86_64 → :amd64.
ARCH="$(uname -m 2>/dev/null || echo unknown)"
if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
  NASANY_IMAGE="mccdingding/nasany-sms:amd64"
  echo "ARCH: x86_64 (amd64) — using amd64 image"
else
  NASANY_IMAGE="mccdingding/nasany-sms:latest"
  echo "ARCH: $ARCH — using arm64 image"
fi

cat > docker-compose.yaml <<EOF
services:
  nasany-sms:
    image: ${NASANY_IMAGE}
    container_name: nasany-sms
    restart: unless-stopped
    network_mode: host
    devices:
      - ${TTY}:${TTY}
      - /dev/snd:/dev/snd
    volumes:
      - ./data:/var/lib/nasany
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
      - /var/lib/nasany
      - -call-history-store
      - /var/lib/nasany/call-history.json
      - -remote-listen
      - 127.0.0.1:7578
      - -remote-host
      - localhost
      - -remote-control
      - -remote-allow-loopback
      - -remote-recordings-dir
      - /var/lib/nasany/call-recordings
      - -remote-cookie-auth
      - -remote-cookie-auth-password-hash-file
      - /var/lib/nasany/auth/password-hash
      - -remote-cookie-auth-username-file
      - /var/lib/nasany/auth/username
      - -remote-cookie-auth-initialized-file
      - /var/lib/nasany/auth/initialized
      - -remote-cookie-auth-secret-file
      - /var/lib/nasany/auth/session-secret
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
      - /var/lib/nasany/vapid-private-key
      - -remote-push-vapid-subject
      - mailto:${EMAIL:-admin@${DOMAIN}}
      - -remote-push-subscriptions-file
      - /var/lib/nasany/push/subscriptions.json
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
    # Admin API disabled via `admin off` in the Caddyfile (avoids :2019 clashes).
    command: caddy run --config /etc/caddy/Caddyfile --adapter caddyfile

volumes:
  caddy_data:
EOF
echo "OK: docker-compose.yaml"

# DuckDNS IP auto-update (home broadband: IP changes, domain must follow).
# Only when a token + domain are provided. Uses DuckDNS's free HTTP API:
#   https://www.duckdns.org/update?domains=<d>&token=<t>&ip=   (ip empty = auto)
if [[ -n "${NASANY_DUCKDNS_TOKEN:-}" && -n "$DOMAIN" ]]; then
  NOREDIR_D=''
  if [[ "$DOMAIN" == *".duckdns.org" ]]; then NOREDIR_D="${DOMAIN%.duckdns.org}"; else NOREDIR_D="$DOMAIN"; fi
  cat > duckdns-update.sh <<EOF
#!/usr/bin/env bash
# DuckDNS IP updater for ${NOREDIR_D} (auto-detects current public IP on each run)
curl -fsS --max-time 15 "https://www.duckdns.org/update?domains=${NOREDIR_D}&token=${NASANY_DUCKDNS_TOKEN}&ip=" || true
EOF
  chmod +x duckdns-update.sh
  echo "OK: duckdns-update.sh (${NOREDIR_D}.duckdns.org)"

  # Install a 5-minute cron if not already present (DuckDNS recommends <=5min).
  if ! crontab -l 2>/dev/null | grep -q "duckdns-update"; then
    ( crontab -l 2>/dev/null; echo "*/5 * * * * $(pwd)/duckdns-update.sh >/dev/null 2>&1" ) | crontab -
    echo "OK: installed 5-min cron for DuckDNS IP update"
  else
    echo "NOTE: DuckDNS cron already installed"
  fi
fi

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
