<div align="center">

# 📡 NasAnySim

**Turn a 4G module plugged into your NAS into a private phone & SMS gateway — reachable from any browser.**

[简体中文](README.md) · [English](README.en.md)

![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue.svg)
![Platform](https://img.shields.io/badge/Platform-ARM64%20%2F%20x86_64-green.svg)
![Version](https://img.shields.io/badge/Version-1.0.0--rc.4-lightgrey.svg)

</div>

## ✨ Overview

NasAnySim is a **self-hosted cellular gateway** that runs on an ARM Linux NAS (fnOS / OpenMediaVault / Debian all work).

Plug in a **DJI / BAIWANG 4G module** (Quectel-compatible AT) with a SIM card, and the gateway turns that SIM into:

> 📱 **Private phone** · 💬 **SMS** · 🔔 **Incoming-call/SMS notifications** · 🎙 **Call recording**

Reachable from any modern browser (iOS PWA, Android, desktop) — no need to carry a second phone.

<div align="center">

![NasAnySim architecture](brand/architecture-en.svg)

*How it works: phone → NAS gateway → 4G module & SIM*

</div>

---

## 🚀 Features

| Feature | Description |
|---------|-------------|
| 📱 SMS | Full conversation UI, durable store, multi-device sync |
| 📞 Voice calls | WebRTC inbound/outbound, TURN relay for NAT traversal |
| 🔔 Background push | Incoming call & SMS notifications even when the PWA is closed |
| 🎙 Call recording | Recorded on the NAS, playable/deletable from the PWA |
| 🔐 Secure auth | Persistent cookie auth, works behind Caddy forward_auth |
| 🐳 One-command deploy | Single container (ARM64 / x86_64), `docker compose up` and go |

---

## ⚖️ Licensing & Distribution

> **Closed-source · Image-only distribution · Free for personal use · No commercial resale**

This project ships as **prebuilt Docker images** (ARM64 / x86_64). The source is **not published**; the images are **free for personal use but not for commercial resale or redistribution**.

**Why closed-source:** the early USB/AT/eSIM/modem-management foundation derives from **VoHive / DJOneHub** ([github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)) under its own **"Changes and New Works License"**; the UAC probing and QDC507 audio path reference **MaVo** ([github.com/moluncn/mavo](https://github.com/moluncn/mavo), MIT) and similar public projects. These upstream obligations constrain how derivatives may be redistributed.

Full notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

**Terms of use:** free for personal self-hosted use; **commercial resale, rebranding-for-sale, and redistribution of the images or their contents are prohibited.**

---

## 📦 Deployment

### You only need 3 things

| # | What you do | Notes |
|---|-------------|-------|
| 1 | 🖥 **A NAS** (ARM64 or x86_64) | with Docker installed (fnOS / rk35xx verified) |
| 2 | 📶 **A 4G module + SIM** | plugged into the NAS, enumerated as `/dev/ttyUSB2` |
| 3 | 🌐 **A domain** | pointing to your home public IP (DDNS works too) |

> ⚠️ **System setup**: **ModemManager must be disabled** (otherwise it steals the module serial port).

### One-command deploy (recommended)

**No script editing needed** — download the script and put your domain + email in the command:

```bash
# 1. Download the deploy script
curl -fsSL https://raw.githubusercontent.com/mccding/NasAnySim/main/deploy/deploy.sh -o deploy.sh

# 2. One-command deploy (replace "your-domain.example.com"; email auto-issues the HTTPS cert)
bash deploy.sh your-domain.example.com you@example.com
```

The script automatically: creates data dirs, generates secrets, configures the Caddy reverse proxy + HTTPS cert, and starts the gateway and TURN relay. **The only thing you do on your router** is forward two ports (see table below).

When done, open:

```
https://your-domain:7577/remote/     # default login admin / admin
```

> ⚠️ **Change the default password immediately after first login.**

### Ports to forward on your router

| Port | Protocol | Purpose | Forward? |
|------|----------|---------|----------|
| `7577` | TCP | HTTPS PWA | ✅ required |
| `3478` | UDP | TURN voice relay | ✅ required |
| `5349` | TCP | TURN TLS (enabled when certs detected) | optional |

### Common cases

**Already running Caddy/Nginx?** Nothing to do — the script auto-detects that 7577 is in use, skips its own Caddy, and your proxy is untouched. A ready-made site config is written to `./caddy/Caddyfile` for you to copy into your proxy.

**Module not on `/dev/ttyUSB2`?** (Most users can ignore this.)

Only needed if the script prints `WARN: /dev/ttyUSB2 not found`. First check which serial port your module is on:

```bash
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

If it shows `/dev/ttyUSB2` (the default), nothing to do. If it's something else (e.g. `/dev/ttyACM0`), tell the script:

```bash
bash deploy.sh your-domain.example.com you@example.com /dev/ttyACM0
```

## 🔌 Ports

| Port | Binding | Service | Purpose |
|------|---------|---------|---------|
| `7577` | public (Caddy) | HTTPS PWA | `https://your-domain:7577/remote/` |
| `7578` | 127.0.0.1 | Remote gateway | reverse-proxy target, not public |
| `7576` | 127.0.0.1 | Local console | loopback diagnostics |
| `3478` | public (TURN) | TURN UDP/TCP | WebRTC voice relay (required for calls) |
| `5349` | public (TURN) | TURN TLS | WebRTC voice relay (encrypted) |

---

## 🔐 Authentication

### First login

A fresh deployment seeds the default credential **`admin` / `admin`**.

> ⚠️ **Change the password immediately after your first login.** Do not leave the default credential on a public-facing deployment.

### Change the password (terminal)

SSH into the NAS and run:

```bash
# Reset the login password
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-password "YOUR_NEW_PASSWORD" \
  -remote-reset-password-file /var/lib/maccellular/auth/password-hash

# Reset the login username
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-username "YOUR_NEW_USERNAME" \
  -remote-reset-username-file /var/lib/maccellular/auth/username
```

> ⚠️ After resetting, **restart the container** (`docker compose restart nasany-sms`) for the new credentials to take effect.

---

## ⚙️ Module Setup

On connect, the gateway **configures the module automatically** — no manual AT commands needed:

- ✅ **CLCC mode 0 only** — tracks only real voice calls
- ✅ **ModemManager disabled** — the module's serial port is exclusively owned by the gateway
- ✅ **USB composition query** — `AT+QCFG="USBCFG"` verifies the voice-capable profile
- ✅ **PCM/DAI voice routing** — `AT+QPCMV` / `AT+QDAI` verified
- ✅ **UAC + QDC507 audio** — module-side runtime pushed via ADB after reboot; voice route auto-started

**Required module environment:** enumerated as `/dev/ttyUSB2` · ModemManager disabled · SIM registered · TURN relay reachable

---

## 📱 Mobile install (iOS PWA)

1. Open `https://your-domain:7577/remote/` in Safari
2. Log in
3. Share → **Add to Home Screen**
4. Runs as a standalone full-screen PWA

---

## ❓ FAQ

<details>
<summary><b>Why is it closed-source?</b></summary>

Upstream obligations (VoHive's "Changes and New Works License", libusb LGPL, MaVo reference) constrain how derivatives may be redistributed; we distribute images only.
</details>

<details>
<summary><b>Does it work on x86_64?</b></summary>

Yes. Both **ARM64** and **x86_64** images are provided; the one-command script auto-detects your NAS architecture and pulls the matching image.
</details>

<details>
<summary><b>Which modules are supported?</b></summary>

DJI / BAIWANG modules with the QDC507 voice path (Quectel-compatible AT). The gateway auto-detects the module via USB AT or `/dev/ttyUSB2`.
</details>

<details>
<summary><b>Can I sell this?</b></summary>

No. The images are free for personal self-hosted use; commercial resale and redistribution are prohibited.
</details>

---

## 🙏 Acknowledgements

- **MacCellular** ([github.com/yuexiazhuojiu-byte/MacCellular](https://github.com/yuexiazhuojiu-byte/MacCellular)) — the project this one descends from; the first open-source Mac SMS + phone gateway. Thanks to the author for the great work
- **VoHive / DJOneHub** ([github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)) — early USB/AT, eSIM, and modem-management foundation. `Required Notice: Copyright iniwex5`
- **MaVo** ([github.com/moluncn/mavo](https://github.com/moluncn/mavo), MIT) — UAC probing and QDC507 audio-path reference
- **Celldock** and similar public projects — technical reference
- **Pion WebRTC** (MIT), **libusb** (LGPL-2.1), **coturn** — runtime dependencies

Full notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

---

## 💖 Support

If this project is useful to you, consider supporting its development:

<div align="center">

![Support](brand/support-qr.png)

*Scan to support*

</div>
