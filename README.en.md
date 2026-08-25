<div align="center">

<img src="brand/icon.png" width="96" alt="NasAnySim icon">

# NasAnySim

**Turn a 4G module attached to your NAS into a private phone and SMS gateway reachable from your phone browser.**

[简体中文](README.md) · [English](README.en.md) · [Changelog](CHANGELOG.en.md)

[![Platform](https://img.shields.io/badge/platform-ARM64%20%7C%20amd64-16a085?style=flat-square)](https://hub.docker.com/r/mccdingding/nasany-sms)
[![Docker Hub](https://img.shields.io/docker/pulls/mccdingding/nasany-sms?logo=docker&style=flat-square)](https://hub.docker.com/r/mccdingding/nasany-sms)
[![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial-2563eb?style=flat-square)](LICENSE)
[![Verification](https://img.shields.io/badge/verification-clean%20dual--arch%20deploy-10b981?style=flat-square)](docs/VERIFICATION.en.md)

</div>

> **Distribution boundary:** this public repository contains documentation, the deployment script, and release resources only. The runtime is delivered as a prebuilt Docker image. Source code, certificates, keys, and customer-machine runtime data are not published.

<div align="center">

![NasAnySim architecture](brand/architecture-en.svg)

*Phone browser → HTTPS/Caddy → gateway → 4G module and physical SIM*

</div>

## Overview

NasAnySim is a self-hosted cellular gateway. Plug a DJI / BAIWANG (Quectel-compatible AT) 4G module into a Linux NAS and use its SIM for SMS and voice calls from a modern browser.

- **SMS:** send, receive, store, and synchronize conversations;
- **Voice:** WebRTC inbound/outbound calls, TURN relay, and call recording;
- **Notifications:** incoming-call and SMS Web Push;
- **Deployment:** ARM64 and amd64 images with automatic architecture selection;
- **Access:** Caddy HTTPS and a mobile PWA, without requiring Tailscale.

> This project is based on [MacCellular 1.0.0-rc.4](https://github.com/yuexiazhuojiu-byte/MacCellular) and related upstream work. Copyright, licensing, and required notices are in [LICENSE](LICENSE), [NOTICE](NOTICE), and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## One-command deployment

### Requirements

| Item | Requirement |
|---|---|
| Host | Linux ARM64 or amd64 with Docker Compose installed |
| Hardware | A supported 4G module, physical SIM, and USB connection; DJI / BAIWANG QDC507 voice path was verified |
| Domain | A domain pointing to the host's public IP; DuckDNS is recommended for home broadband |
| Privileges | Root or working `sudo` for first-time host ADB and serial setup |

### Step 1: identify the actual serial port

The current dual-host-tested version does **not** provide a `--detect-tty` subcommand. Do not assume every host uses `/dev/ttyUSB2`; inspect the customer host first:

```bash
uname -m
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

The DJI / BAIWANG modules used for this acceptance exposed the AT port as `/dev/ttyUSB2`. Numbering can change with multiple modules or a different USB topology. Confirm the AT port and pass it as the third argument.

### Step 2: download and deploy

```bash
mkdir -p nasanysim && cd nasanysim
curl -fsSL https://raw.githubusercontent.com/mccding/NasAnySim/main/deploy/deploy.sh -o deploy.sh
chmod 700 deploy.sh

# Replace /dev/ttyUSB2 with the customer's actual AT port
bash deploy.sh nasanysim.duckdns.org you@example.com /dev/ttyUSB2
```

You do **not** need to edit the script, manually chmod coturn files, copy certificates, or start ADB yourself. The script automatically:

1. checks Docker, host architecture, and the serial port;
2. installs/starts a host ADB server bound only to `localhost:5037` and waits for readiness;
3. stops ModemManager when present so it cannot hold the module port;
4. generates data keys, TURN configuration, and the module bootstrap capability;
5. applies the directory, configuration, and certificate permissions required by coturn's unprivileged `nobody` process;
6. pulls `mccdingding/nasany-sms:latest` on ARM64 or `:amd64` on amd64;
7. starts the gateway, TURN, and Caddy containers and force-recreates TURN after certificate changes;
8. retries module bootstrap until the backend and module runtime report ready.

Open this URL when it finishes:

```text
https://your-domain:7577/remote/
```

A fresh deployment starts with `admin / admin`. Change the password immediately.

## HTTPS and certificate paths

The script tries certificate paths in this order:

1. existing user certificates at `caddy/fullchain.pem` and `caddy/privkey.pem`;
2. Let's Encrypt HTTP-01 when the public HTTP conditions are available;
3. Let's Encrypt DNS-01 with a DuckDNS token, which **does not require public port 80**;
4. a clear failure if no real certificate path is available. It does not silently turn a production deployment into a browser-warning self-signed setup.

HTTP-01 is often unavailable on home broadband. For that case use DuckDNS DNS-01. An interactive terminal can paste the token when prompted; SSH and CI runs should use `.env`:

```bash
umask 077
printf '%s\n' 'NASANY_DUCKDNS_TOKEN=[REDACTED]' > .env
chmod 600 .env
# Replace [REDACTED] locally; never commit .env
bash deploy.sh nasanysim.duckdns.org you@example.com /dev/ttyUSB2
```

## Built-in DuckDNS dynamic-IP update

Dynamic-IP maintenance for DuckDNS is built into the dual-host-tested script. **You do not download another updater or write a cron job yourself.** It activates when a domain and `NASANY_DUCKDNS_TOKEN` are both supplied; use that token only with a DuckDNS domain.

The deployment script then:

1. generates `duckdns-update.sh` in the deployment directory;
2. marks it executable; its exact mode depends on the deployment directory and system `umask`;
3. leaves `ip=` empty by default so DuckDNS detects the public IP from the request source;
4. uses an explicitly supplied `NASANY_PUBLIC_IP` when you need to override source-IP detection;
5. installs a five-minute crontab entry;
6. appends the DuckDNS response to `/var/log/duckdns-update.log`.

Check the installed updater:

```bash
crontab -l | grep duckdns-update
ls -l duckdns-update.sh
./duckdns-update.sh            # optional manual run
```

For a non-DuckDNS domain, do not supply a DuckDNS token to this script; use that provider's DDNS mechanism instead. See [DuckDNS details](docs/DUCKDNS.en.md) for the exact tested behavior.

> **Security:** `.env`, `duckdns-update.sh`, certificates, and private keys are local secrets. Do not upload or paste them into public issues. Rotate a DuckDNS token if it has been exposed.

## Public ports and security boundary

Forward these public ports to the LAN address of the NasAnySim host:

| Port | Protocol | Purpose | Requirement |
|---:|:---:|---|---|
| `7577` | TCP | HTTPS PWA and remote gateway | required |
| `3478` | UDP | TURN connection setup | required |
| `49160-49167` | UDP | TURN relay media range | required for calls |
| `5349` | TCP | TURN TLS | recommended when TLS is enabled |

Keep these ports loopback-only and **do not forward them to the Internet**:

| Port | Binding | Purpose |
|---:|---|---|
| `7576` | `127.0.0.1` | backend management/diagnostics |
| `7578` | `127.0.0.1` | Caddy reverse-proxy target |
| `5037` | `localhost` | host ADB server |

Forwarding `7577` without the `49160-49167/UDP` relay range often produces a working webpage but a “cannot reach public relay” call failure. See [Ports and security](docs/PORTS.en.md).

## Existing Caddy/Nginx or a port conflict

The current dual-host-tested script starts bundled Caddy and requires host port `7577` to be free. `NASANY_SKIP_CADDY` is not a public interface covered by the dual-host acceptance. If another proxy already owns `7577`, do not run the current one-command path or expose internal ports as a workaround; complete and retest a separate proxy integration first.

## Images and architecture

| Host architecture | Docker Hub image |
|---|---|
| ARM64 / AArch64 | `mccdingding/nasany-sms:latest` |
| amd64 / x86_64 | `mccdingding/nasany-sms:amd64` |

The script selects the matching image. Do not mix ARM64 and amd64 images. The runtime is distributed as a closed prebuilt image; this repository does not contain source code, Go caches, customer certificates, or build contexts.

## Mobile use

1. Open `https://your-domain:7577/remote/` in Safari or Chrome;
2. log in and change the default password;
3. on iPhone choose Share → **Add to Home Screen**; Android can install the PWA from the browser menu;
4. before the first call, confirm the TURN port range is forwarded.

## Troubleshooting

- **No serial port:** inspect `/dev/ttyUSB*` and `/dev/ttyACM*`, then confirm the module USB connection and AT port;
- **Webpage unavailable:** check `7577/TCP`, DNS, and Caddy logs;
- **Webpage works but relay fails:** check `3478/UDP`, `49160-49167/UDP`, and preferably `5349/TCP` with valid certificates;
- **Certificate issuance fails:** use a DuckDNS token and DNS-01 on home broadband instead of repeatedly retrying HTTP-01;
- **ADB error:** the script should install and bind ADB to `localhost:5037`; check `systemctl status nasany-adb-server.service`;
- **ModemManager owns the port:** the script disables it when systemd is available; otherwise confirm no other process has the TTY open.

See [Troubleshooting](docs/TROUBLESHOOTING.en.md) for the full checklist.

## Verification status

The current `deploy/deploy.sh` has been restored byte-for-byte to the identical script that passed clean ARM64 and amd64 acceptance. Its SHA-256 is `bd9f02a8ff7d5cd6871467f394d45967e446978e770a31c9c5a32b2b9ec104de`. Docker Hub image pull, DNS-01 certificates, TURN TLS 5349, loopback host ADB, module bootstrap/voice runtime, and real phone/SMS end-to-end checks all passed. See [Dual-architecture verification](docs/VERIFICATION.en.md).

## License and acknowledgements

The project is distributed as prebuilt Docker images. Personal self-hosted use is free; commercial resale, rebranding for sale, and redistribution of the images or their contents are prohibited. The authoritative terms are in [LICENSE](LICENSE).

Thanks to:

- [MacCellular](https://github.com/yuexiazhuojiu-byte/MacCellular), the earlier macOS SMS/phone gateway;
- [VoHive / DJOneHub](https://github.com/iniwex5/vohive), the early USB/AT, eSIM, and modem-management foundation;
- [MaVo](https://github.com/moluncn/mavo), the UAC and QDC507 audio-path reference;
- Pion WebRTC, libusb, coturn, and the other runtime dependencies.

See [NOTICE](NOTICE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for complete notices.

---

## 💖 Support

If this project is useful to you, consider supporting its development:

<div align="center">

![Support](brand/support-qr.png)

*Scan to support*

</div>
