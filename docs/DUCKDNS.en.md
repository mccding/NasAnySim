# DuckDNS: certificates and dynamic public IP

The one-command script includes two DuckDNS capabilities:

1. **DNS-01 certificates:** use a DuckDNS token to obtain a Let's Encrypt certificate when public port 80 is unavailable;
2. **Dynamic-IP updates:** generate a protected updater and install a five-minute cron entry after deployment.

You do not download another DuckDNS updater or write a cron job manually.

## Supplying the token

An interactive terminal can run the normal command and paste the token when prompted:

```bash
bash deploy.sh <domain> <email> <TTY>
```

SSH, CI, and other non-TTY environments should create `.env` in the deployment directory:

```bash
umask 077
printf '%s\n' 'NASANY_DUCKDNS_TOKEN=[REDACTED]' > .env
chmod 600 .env
bash deploy.sh <domain> <email> <TTY>
```

Replace `[REDACTED]` locally only. Never upload `.env` to GitHub.

## How the built-in updater works

The updater is enabled only when the domain matches `*.duckdns.org` and a token is supplied. The script then:

- creates `duckdns-update.sh` in the deployment directory;
- sets it to owner-only mode (`700`);
- sends DuckDNS an empty `ip=` by default so DuckDNS detects the request source IP;
- uses `NASANY_PUBLIC_IP` when you explicitly need to override source-IP detection;
- installs a `*/5 * * * *` cron entry;
- appends the response to `/var/log/duckdns-update.log`.

Check it with:

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
```

If `crontab` is unavailable, the script keeps the owner-only updater and prints a warning; use the host's existing scheduler to invoke it.

## Security

The updater URL contains the token. Therefore:

- never paste `duckdns-update.sh` into an issue, chat, or public log;
- keep its `700` mode;
- keep `.env`, certificates, private keys, and the updater inside the deployment directory;
- rotate the token in DuckDNS if it was exposed;
- for a non-DuckDNS domain, use that DNS provider's DDNS mechanism instead.

## Explicit public IP

Normally `NASANY_PUBLIC_IP` is not needed. Set it only when a proxy, TUN, or unusual egress causes DuckDNS to see the wrong source address:

```bash
NASANY_PUBLIC_IP=<your-public-ip> bash deploy.sh <domain> <email> <TTY>
```

Do not put a real public IP or token in public documentation or commits.
