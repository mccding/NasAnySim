# Changelog

## 1.0.0-rc.5 — 2026-08-25

- Completed clean one-command deployment acceptance on Linux amd64 and ARM64;
- added `bash deploy.sh --detect-tty` to inspect architecture, serial ports, USB, ALSA, and ADB before deployment;
- hardened loopback host ADB, readiness polling, and automatic module-bootstrap retries;
- hardened coturn `nobody` permissions, TURN TLS 5349, and forced recreation after config changes;
- prevented non-interactive SSH/CI runs from exiting on DuckDNS/acme.sh prompts;
- documented built-in DuckDNS DNS-01 certificates and dynamic-IP maintenance with an owner-only updater and five-minute cron;
- clarified public ports, internal ports, router forwarding, and security boundaries;
- redesigned the Chinese and English README files and added port, DuckDNS, troubleshooting, and dual-architecture verification docs;
- kept the public repository within its documentation/deployment-resource boundary: no source code, certificates, tokens, private keys, or customer runtime data.
