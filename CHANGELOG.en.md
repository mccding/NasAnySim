# Changelog

## 1.0.0-rc.6 — 2026-08-25

- Restored public `deploy/deploy.sh` byte-for-byte to the identical script used for the final successful ARM64 and amd64 deployments;
- recorded the dual-host-tested script SHA-256: `bd9f02a8ff7d5cd6871467f394d45967e446978e770a31c9c5a32b2b9ec104de`;
- restored the deployment contract test to the version that actually passed with that script;
- removed README promises for post-acceptance changes, including `--detect-tty`, Caddy opt-out, and a guaranteed `700` DuckDNS updater mode;
- separated dual-host-tested behavior from improvements that require another clean dual-architecture acceptance;
- retained the bilingual professional documentation, port guidance, troubleshooting, verification record, and original support QR section.

## 1.0.0-rc.5 — not recommended

This tag changed `deploy.sh` after dual-host acceptance without rerunning clean ARM64 and amd64 deployments, so it cannot inherit the “one-pass dual-host verified” claim. The immutable tag remains as history; use `rc.6` or current `main` instead.
