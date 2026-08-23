<p align="center">
  <img src="docs/brand/icon.svg" width="112" alt="NasAnySim icon">
</p>

<h1 align="center">NasAnySim</h1>

<p align="center"><strong>Turn a cellular module plugged into your NAS into a private phone & SMS gateway — reachable from any browser.</strong></p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="#deployment">Deployment</a> ·
  <a href="#authentication">Authentication</a> ·
  <a href="#licensing">Licensing</a>
</p>

---

## Overview

NasAnySim is a **self-hosted cellular gateway** that runs on an ARM Linux NAS (e.g. fnOS / OpenMediaVault / Debian). Plug in a **DJI / BAIWANG 4G module** (Quectel-compatible AT), insert a SIM card, and the gateway turns the SIM into a private phone + SMS service reachable from any modern browser (iOS PWA, Android, desktop).

**Features**

- 📱 **SMS send / receive** — full conversation UI, durable store, sync across devices
- 📞 **Voice calls** — inbound & outbound over WebRTC, with TURN relay for NAT traversal
- 🔔 **Background notifications** — incoming call & SMS Web Push even when the PWA is closed
- 🎙 **Call recording** — recorded on the NAS, playable/deletable from the PWA
- 🔐 **Persistent cookie auth** — works behind Caddy / any forward_auth proxy
- 🐳 **Single-container ARM64 image** — `docker compose up` on an ARM NAS

---

## Licensing & Distribution Model

> **Closed-source, image-only distribution.**

This project ships as **prebuilt ARM64 Docker images only**. The source is **not published**, and the images are **free for personal use but not for commercial resale or redistribution**.

The decision is driven by upstream obligations:

- The early USB/AT/eSIM/modem-management foundation derives from **VoHive / DJOneHub** ([github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)) under its own **"Changes and New Works License"** — `Required Notice: Copyright iniwex5`.
- The UAC probing and QDC507 audio path reference **MaVo** ([github.com/moluncn/mavo](https://github.com/moluncn/mavo), MIT) and **Celldock** and similar public implementations.
- Runtime dependencies include **libusb** (LGPL-2.1) and **Pion WebRTC** (MIT).

These upstream terms constrain how derivatives may be redistributed, so we distribute binaries rather than source. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the full retained notices.

**Terms of use:** free for personal / self-hosted use; **commercial resale, rebranding-for-sale, and redistribution of the images or their contents are prohibited.**

---

## Deployment

### Prerequisites

- An **ARM64 Linux NAS** with Docker (tested on fnOS, `rk35xx` arm64)
- A **DJI / BAIWANG 4G module** (QDC507 voice path verified; Quectel-compatible AT) with a **SIM card** inserted, enumerated as `/dev/ttyUSB2`
- **ModemManager must be disabled** so the module's serial port is not claimed by the OS
- A domain + HTTPS for the PWA (Caddy reverse proxy recommended), and a reachable TURN relay for voice

### Quick start

```bash
# 1. Create the working directory
mkdir -p /mnt/docker-compose/maccellular && cd /mnt/docker-compose/maccellular

# 2. Save the compose file below as compose.yaml

# 3. Generate a session secret (at least 32 random bytes)
openssl rand -base64 48 > data/auth/session-secret
chmod 600 data/auth/session-secret

# 4. Start the gateway
docker compose up -d

# 5. Open the PWA
#    https://your-domain:7577/remote/
```

### docker-compose.yaml

```yaml
services:
  nasany-sms:
    image: ghcr.io/your-account/nasany-sms:latest   # ARM64 image
    container_name: nasany-sms
    restart: unless-stopped
    network_mode: host
    devices:
      - /dev/ttyUSB2:/dev/ttyUSB2       # Quectel module AT port
      - /dev/snd:/dev/snd               # ALSA PCM for module voice (UAC)
    volumes:
      - ./data:/var/lib/maccellular     # persistent SMS / auth / recordings
      - ./turn-secret:/run/secrets/turn-secret:ro   # coturn REST secret
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    command:
      - -listen
      - 127.0.0.1:7576
      - -port
      - /dev/ttyUSB2
      - -phone-relay-runtime
      - -sms-store
      - /var/lib/maccellular
      - -call-history-store
      - /var/lib/maccellular/call-history.json
      # Remote PWA gateway
      - -remote-listen
      - 127.0.0.1:7578
      - -remote-host
      - localhost
      - -remote-control
      - -remote-allow-loopback
      - -remote-recordings-dir
      - /var/lib/maccellular/call-recordings
      # Cookie auth
      - -remote-cookie-auth
      - -remote-cookie-auth-password-hash-file
      - /var/lib/maccellular/auth/password-hash
      - -remote-cookie-auth-username-file
      - /var/lib/maccellular/auth/username
      - -remote-cookie-auth-initialized-file
      - /var/lib/maccellular/auth/initialized
      - -remote-cookie-auth-secret-file
      - /var/lib/maccellular/auth/session-secret
      # TURN relay for voice
      - -remote-media-turn-host
      - your-domain.example.com
      - -remote-media-turn-secret-file
      - /run/secrets/turn-secret
      - -remote-media-turn-udp-port
      - "3478"
      - -remote-incoming-answer
      - -remote-rescue-hangup
      # Web Push background notifications
      - -remote-push
      - -remote-push-vapid-private-key-file
      - /var/lib/maccellular/vapid-private-key
      - -remote-push-vapid-subject
      - mailto:you@example.com
      - -remote-push-subscriptions-file
      - /var/lib/maccellular/push/subscriptions.json
      - -web-console

  # TURN relay for WebRTC voice (required for calls outside your LAN)
  nasany-turn:
    image: coturn/coturn:latest
    container_name: nasany-turn
    restart: unless-stopped
    network_mode: host
    command:
      - -n
      - --realm=your-domain.example.com
      - --listening-port=3478
      - --tls-listening-port=5349
      - --fingerprint
      - --lt-cred-mech
      - --use-auth-secret
      - --static-auth-secret-file=/run/secrets/turn-secret
      - --cert=/etc/coturn/tls/fullchain.pem
      - --pkey=/etc/coturn/tls/privkey.pem
```

### Reverse proxy (Caddy)

The PWA and API live behind Caddy with a forward-auth login gate:

```caddy
https://your-domain:7577 {
    tls /etc/ssl/fullchain.pem /etc/ssl/privkey.pem

    # Login/logout reachable without a session
    handle /remote/auth/* {
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }

    # PWA icons reachable without a session (iOS "Add to Home Screen")
    handle /remote/*.png {
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }
    handle /remote/*.svg {
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }
    handle /remote/manifest.webmanifest {
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }

    # Everything else requires a signed session cookie
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
```

---

## Ports

| Port | Binding | Service | Purpose |
|------|---------|---------|---------|
| `7577` | public (Caddy) | HTTPS PWA | `https://your-domain:7577/remote/` |
| `7578` | 127.0.0.1 (nasany-sms) | Remote gateway | reverse-proxy target, not public |
| `7576` | 127.0.0.1 (nasany-sms) | Local console | loopback diagnostics |
| `3478` | public (nasany-turn) | TURN UDP/TCP | WebRTC voice relay (required for calls) |
| `5349` | public (nasany-turn) | TURN TLS | WebRTC voice relay (encrypted) |

---

## Authentication

### First login

A fresh deployment seeds the default credential **`admin` / `admin`**.

> ⚠️ **Immediately change the password after your first login.** Do not leave the default credential in place on a public-facing deployment.

### Change the password (terminal)

SSH into the NAS and run the binary inside the container:

```bash
# Reset the login password
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-password "YOUR_NEW_PASSWORD" \
  -remote-reset-password-file /var/lib/maccellular/auth/password-hash

# Reset the login username
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-username "YOUR_NEW_USERNAME" \
  -remote-reset-username-file /var/lib/maccellular/auth/username

# Factory re-init: username=admin, password=<value>, next login is first-run
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-init-credentials "TEMPORARY_PASSWORD" \
  -remote-cookie-auth-password-hash-file /var/lib/maccellular/auth/password-hash \
  -remote-cookie-auth-username-file /var/lib/maccellular/auth/username \
  -remote-cookie-auth-initialized-file /var/lib/maccellular/auth/initialized
```

> The reset command writes the new hash to disk and exits; **restart the container** (`docker compose restart nasany-sms`) for the running process to pick it up.

---

## Module configuration

On connect, the gateway **automatically configures the module** (no manual AT setup):

- **CLCC mode 0 only** — only real voice calls are tracked; mode-1 data sessions are ignored
- **ModemManager disabled** — the module's serial port is exclusively owned by the gateway
- **USB composition query** — `AT+QCFG="USBCFG"` to verify the voice-capable USB profile
- **PCM / DAI voice routing** — `AT+QPCMV` / `AT+QDAI` verified so module audio reaches the host
- **UAC + QDC507 audio** (MaVo-referenced) — module-side voice runtime pushed via ADB after reboot; `qdc507` kernel modules loaded; PCM bridge established; voice route auto-started on answered calls

**Required module environment:**
1. Module enumerated as `/dev/ttyUSB2`
2. ModemManager disabled
3. SIM inserted and registered to the network
4. TURN relay reachable for call audio

---

## Mobile install (iOS PWA)

1. Open `https://your-domain:7577/remote/` in Safari
2. Log in
3. Share → **Add to Home Screen**
4. The app installs as a standalone PWA with full-screen UI

---

## FAQ

**Why is it closed-source?**
Upstream obligations (VoHive's "Changes and New Works License", libusb LGPL, MaVo reference) constrain how derivatives may be redistributed; we distribute images only. See [Licensing](#licensing--distribution-model).

**Does it work on x86_64?**
Currently the image is built for **ARM64** (rk35xx NAS). x86_64 builds may be added later.

**Which modules are supported?**
DJI / BAIWANG modules with the QDC507 voice path (Quectel-compatible AT). The gateway auto-detects the module via USB AT (`discoverDJIUSBDevice`) or `/dev/ttyUSB2`.

**Can I sell this?**
No. The images are free for personal self-hosted use; commercial resale and redistribution are prohibited.

---

## Acknowledgements

- **VoHive / DJOneHub** ([github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)) — early USB/AT, eSIM, and modem-management foundation. `Required Notice: Copyright iniwex5`
- **MaVo** ([github.com/moluncn/mavo](https://github.com/moluncn/mavo), MIT) — UAC probing and QDC507 audio-path reference
- **Celldock** and similar public projects — technical reference
- **Pion WebRTC** (MIT), **libusb** (LGPL-2.1), **coturn** — runtime dependencies

Full notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

---

## Support

If you find this project useful, consider supporting its development:

<div align="center">
  <img src="docs/brand/support-qr.png" width="180" alt="Support / donate QR">
  <p><em>Support this project</em></p>
</div>
