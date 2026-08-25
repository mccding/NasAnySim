# Troubleshooting

## Collect the baseline first

```bash
bash deploy.sh --detect-tty
uname -m
docker ps -a --filter name=nasany
ss -lntup | grep -E ':(5037|5349|7576|7577|7578)\b'
```

Do not delete the data directory first. Preserve the compose output and logs before changing state.

## The webpage is unavailable

1. confirm that the domain's A record points to the current public IP;
2. confirm router forwarding for `7577/TCP`;
3. inspect `nasany-caddy`:

```bash
docker logs --tail=200 nasany-caddy
docker ps --filter name=nasany-caddy
```

If another proxy already owns `7577`, run:

```bash
NASANY_SKIP_CADDY=1 bash deploy.sh <domain> <email> <TTY>
```

Then integrate the generated `caddy/Caddyfile` into the existing proxy.

## The webpage works but calls cannot reach the public relay

Check these in order:

- `3478/UDP` is forwarded;
- the complete `49160-49167/UDP` range is forwarded;
- `5349/TCP` is forwarded when certificates are present;
- `nasany-turn` has no certificate permission error:

```bash
docker logs --tail=200 nasany-turn
ls -ld coturn
ls -l coturn/turnserver.conf coturn/fullchain.pem coturn/privkey.pem
```

The script automatically sets the coturn directory to `755`, the config to `644`, and prepares readable certificate copies for the container's `nobody` process. Users do not need to fix these permissions manually.

## Certificate issuance fails

- on home broadband, do not repeatedly retry HTTP-01;
- provide a DuckDNS token for a `*.duckdns.org` domain and use DNS-01;
- in non-interactive environments provide the token through `.env` or the environment;
- check host time, DNS, and `/tmp/acme-*.log`;
- do not copy an old certificate into a clean acceptance environment as a substitute for a real issuance.

## The module serial port is missing

```bash
bash deploy.sh --detect-tty
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

For multi-port modules, do not rely on the number alone. Use VID:PID and `ID_PATH` from the detector and pass the actual AT port as the third argument.

## ADB errors

The script installs Android platform tools (on supported apt/dnf hosts), creates `nasany-adb-server.service`, and binds only to `localhost:5037`:

```bash
systemctl status nasany-adb-server.service --no-pager
adb -L tcp:localhost:5037 devices -l
ss -lnt | grep ':5037'
```

If you see `0.0.0.0:5037` or `[::]:5037`, stop the exposed ADB server before rerunning the script. Never expose ADB to the Internet.

## Another service owns the module

The script disables ModemManager. On systems without systemd, check which process has the serial port open:

```bash
fuser -v /dev/ttyUSB2
lsof /dev/ttyUSB2 2>/dev/null
```

## DuckDNS is not updating

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
cat /var/log/duckdns-update.log
```

The updater is generated only for `*.duckdns.org` domains when a token is supplied during deployment. Non-DuckDNS domains use their own provider's DDNS mechanism. If the token was exposed, rotate it before regenerating the local `.env` and deployment directory.
