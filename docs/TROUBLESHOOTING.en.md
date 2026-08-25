# Troubleshooting

## Collect the baseline first

```bash
uname -m
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
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

The dual-host-tested script requires `7577` to be free; `NASANY_SKIP_CADDY` is not part of the accepted public interface. If another proxy owns the port, do not run the current one-command path until the proxy integration has been separately retested.

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
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

For multi-port modules, do not rely on the number alone. Confirm the actual AT port and pass it as the third argument. The current tested script has no `--detect-tty` subcommand.

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

## Forgot the username or password

The current image has no permanent account-settings control in the web UI. Use the container's built-in one-shot reset both to disable `admin / admin` after a fresh deployment and to recover a forgotten credential:

```bash
read -r -p 'New username: ' NASANY_NEW_USERNAME
read -r -s -p 'New password (8–128 characters): ' NASANY_NEW_PASSWORD
printf '\n'

if docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-username "$NASANY_NEW_USERNAME" \
  -remote-reset-username-file /var/lib/nasany/auth/username \
  -remote-reset-password "$NASANY_NEW_PASSWORD" \
  -remote-reset-password-file /var/lib/nasany/auth/password-hash; then
  unset NASANY_NEW_USERNAME NASANY_NEW_PASSWORD
  docker restart nasany-sms
else
  unset NASANY_NEW_USERNAME NASANY_NEW_PASSWORD
  echo 'Credential update failed; the container was not restarted.' >&2
fi
```

After the restart, sign in with the new credential and verify that `admin / admin` is rejected. The one-shot reset process is expected to exit immediately; without restarting the main container, the running process will continue using the old credentials held in memory. Never put a real password directly in a command, Compose file, `.env`, or public issue; the built-in reset interface briefly receives it in a one-shot process argument, so use only a trusted NAS administration shell.

## DuckDNS is not updating

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
cat /var/log/duckdns-update.log
```

The current dual-host-tested script generates the updater whenever both domain and token are non-empty, so use a DuckDNS token only with a `*.duckdns.org` domain. Both acceptance hosts had `crontab`. If the token was exposed, rotate it before regenerating the local `.env` and deployment directory.
