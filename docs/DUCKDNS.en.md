# DuckDNS: certificates and dynamic public IP

The published `deploy/deploy.sh` is byte-for-byte identical to the scripts used for the final successful ARM64 and amd64 deployments. Two DuckDNS paths were exercised:

1. **DNS-01 certificates:** use a DuckDNS token to obtain a Let's Encrypt certificate when public HTTP-01 is unavailable;
2. **Dynamic-IP updates:** generate an updater after deployment and install a five-minute cron entry.

## Supplying the token

An interactive terminal prompts when a token is needed. SSH, CI, and other non-TTY environments should create `.env` in a private deployment directory:

```bash
umask 077
printf '%s\n' 'NASANY_DUCKDNS_TOKEN=[REDACTED]' > .env
chmod 600 .env
bash deploy.sh <DuckDNS-domain> <email> <TTY>
```

Replace `[REDACTED]` only on the customer host. Never commit `.env`.

## Exact dual-host-tested behavior

When both the domain and `NASANY_DUCKDNS_TOKEN` are non-empty, the script:

- creates `duckdns-update.sh` in the deployment directory;
- marks it executable with `chmod +x`;
- sends DuckDNS an empty `ip=` by default so DuckDNS detects the request source address;
- uses `NASANY_PUBLIC_IP` when explicitly supplied;
- installs a `*/5 * * * *` crontab entry;
- appends responses to `/var/log/duckdns-update.log`.

Both acceptance hosts had `crontab`. The verified script does not contain a continue-with-warning path when `crontab` is unavailable, so check a new host first:

```bash
command -v crontab
```

Verify the installed updater:

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
```

## Boundaries

- use `NASANY_DUCKDNS_TOKEN` only with a `*.duckdns.org` domain;
- for a non-DuckDNS domain, do not pass a DuckDNS token; use that DNS provider's DDNS mechanism;
- the tested script uses `chmod +x`; it does not promise mode `700`. The exact mode depends on the private deployment directory and system `umask`;
- both clean acceptance runs used root in a private deployment directory;
- normally leave `NASANY_PUBLIC_IP` empty; set it only when a proxy or TUN breaks source-address detection;
- `.env`, `duckdns-update.sh`, certificates, and private keys contain secrets and must not be uploaded or pasted into public issues;
- rotate the DuckDNS token immediately if it was exposed.

## Verified script fingerprint

```text
SHA-256 bd9f02a8ff7d5cd6871467f394d45967e446978e770a31c9c5a32b2b9ec104de
```

Any later script change—including permission hardening, no-crontab compatibility, new flags, or auto-detection—requires another clean ARM64 and amd64 deployment before it can inherit the “dual-host verified” claim.
