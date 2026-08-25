# Dual-architecture verification

## Scope

This record covers the release-candidate checks that were actually executed and read back. It is not an unconditional compatibility promise for every 4G module, router, or carrier.

## Result

| Platform | Image source | Clean-directory deploy | HTTPS/DNS-01 | TURN TLS 5349 | ADB/module runtime | Phone/SMS E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| Linux amd64 / x86_64 | Docker Hub `:amd64` | pass | pass | pass | pass | pass |
| Linux arm64 / AArch64 | Docker Hub `:arm64` / `:latest` | pass | pass | pass | pass | pass |

## Verified items

- each host started from a cleaned environment without relying on old containers, images, ADB servers, or certificates;
- the customer host received only the public deployment script and Docker image, not source code, `.git`, Go caches, or build context;
- the script selected the image matching the host architecture;
- host ADB listened only on `localhost:5037` and was persisted with systemd;
- the module bootstrap could initially be not-ready; the script retried and required `Ready=true`;
- coturn directory, config, and `nobody`-readable certificate permissions were handled by the script;
- Caddy HTTPS, Let's Encrypt DNS-01, and TURN TLS 5349 were read back;
- ARM64 and amd64 module voice runtime, ALSA helper, and ADB/UAC topology were verified;
- real mobile dialing, answering, two-way audio, SMS send/receive, and post-hangup state were tested;
- no stale call remained in `AT+CLCC` after hangup.

## Pre-publish checks

```bash
bash deploy/deploy_contract_test.sh
bash -n deploy/deploy.sh
git diff --check
```

Also confirm that the public commit contains no `.env`, certificates, private keys, `duckdns-update.sh`, customer addresses, SSH details, or tokens. Read back Docker Hub tags and digests from the registry.

## Boundaries

- `ttyUSB` numbering changes with USB topology; run `--detect-tty` on first use;
- HTTP-01 availability on home broadband must not be assumed; DuckDNS DNS-01 is recommended;
- calls depend on correct router forwarding for the complete TURN port range;
- `7576`, `7578`, and `5037` are not public services;
- the closed-source runtime is distributed as a prebuilt image and is not included in this public repository.
