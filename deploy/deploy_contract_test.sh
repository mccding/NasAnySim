#!/usr/bin/env bash
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy.sh"

bash -n "$script"

python3 - "$script" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
text = path.read_text()

if "# Admin API disabled via `" in text:
    raise SystemExit("unquoted heredoc still contains executable backticks")

try:
    start = next(i for i, line in enumerate(lines) if 'BOOTSTRAP_JSON="$(curl ' in line)
except StopIteration:
    raise SystemExit("bootstrap curl block not found")

expected = [
    '      -H "X-NasAny-Bootstrap-Token: ${BOOTSTRAP_TOKEN}" \\',
    '      http://127.0.0.1:7576/api/module/bootstrap)" \\',
]
if lines[start + 1] != expected[0] or lines[start + 2] != expected[1]:
    raise SystemExit(
        "bootstrap curl continuation is malformed: "
        + repr(lines[start:start + 3])
    )

# The module ADB/voice runtime may need seconds after container start, so the
# bootstrap MUST be retried (e.g. 409/not-ready) before failing the deploy.
full = "\n".join(lines)
for marker in ("for attempt in 1 2 3 4 5 6", "BOOTSTRAP_OK", "sleep 5"):
    if marker not in full:
        raise SystemExit("bootstrap retry loop is missing marker: " + marker)
if "bootstrap did not reach ready" not in full:
    raise SystemExit("bootstrap final failure message is missing")
if "grep -qiE" not in full:
    raise SystemExit("bootstrap ready check must be case-insensitive (JSON uses \"Ready\")")

# TURN TLS 5349 is the proven working relay path (UDP 3478 is unreliable from
# cellular). User certs must be shared with coturn with a readable privkey, and
# the turn container must be force-recreated to apply regenerated config.
for marker in (
    "cp caddy/fullchain.pem coturn/fullchain.pem",
    "chmod 644 coturn/privkey.pem",
    "force-recreate nasany-turn",
):
    if marker not in full:
        raise SystemExit("TURN TLS handling is missing marker: " + marker)

# Interactive prompts must be guarded by -t 0 so non-interactive runs (SSH
# without TTY, CI) fall through instead of dying on read EOF under set -e.
if "[[ -t 0 ]]" not in full:
    raise SystemExit("interactive read prompts must be guarded by [[ -t 0 ]]")
key_count = text.count("read -r -p")
guarded = text.count("if [[ -t 0 ]]; then\n      read -r -p")
if guarded < 1:
    raise SystemExit("no read prompts are inside a -t 0 guard")

# The host ADB server needs a readiness poll: adb's first start (key
# generation) can lag systemd's active state by a few seconds.
if "did not become ready" not in full or "for _ in $(seq 1 30)" not in full:
    raise SystemExit("host ADB readiness must poll instead of failing immediately")

# coturn runs as nobody: the config dir and turnserver.conf must be readable
# even under a 077 umask, or coturn silently drops TLS/listening config.
if "chmod 755 coturn" not in full or "chmod 644 coturn/turnserver.conf" not in full:
    raise SystemExit("coturn dir/config must be chmod'ed readable for nobody")

PY

echo "deploy contract tests passed"
