# Ports and security boundary

NasAnySim separates the public phone-browser entry point from the internal control plane. Forward only the web entry point and TURN relay ports; keep the management interfaces and host ADB off the Internet.

## Public forwards

| Port | Protocol | Purpose | Required |
|---:|:---:|---|:---:|
| `7577` | TCP | Caddy HTTPS, PWA, and remote access | yes |
| `3478` | UDP | TURN connection setup | yes |
| `49160-49167` | UDP | TURN relay media range | required for calls |
| `5349` | TCP | TURN TLS relay | recommended when certificates are enabled |

Forward these ports from the router to the LAN IP of the NasAnySim host. Do not forward only one port from `49160-49167/UDP`; a working webpage does not prove that WebRTC media is reachable.

## Loopback-only ports

| Port | Binding | Purpose | Internet forward |
|---:|---|---|:---:|
| `7576` | `127.0.0.1` | backend console and diagnostics | never |
| `7578` | `127.0.0.1` | Caddy reverse-proxy target | never |
| `5037` | `localhost` | host ADB server | never |

The deployment script refuses to continue when ADB is listening beyond loopback. Do not bind `5037` to `0.0.0.0` just to make it visible to the container.

## Router checklist

1. Confirm that the domain resolves to the home public IP;
2. forward `7577/TCP` and verify the HTTPS page;
3. forward `3478/UDP` and `49160-49167/UDP`;
4. when certificates are present, forward `5349/TCP`; it is the more reliable TURN-TLS path on many cellular networks;
5. test from the phone's cellular network, not only from the same LAN.

## Existing reverse proxy

If an existing Caddy/Nginx instance already owns `7577`, explicitly skip bundled Caddy:

```bash
NASANY_SKIP_CADDY=1 bash deploy.sh <domain> <email> <TTY>
```

Integrate the generated `caddy/Caddyfile` site logic into the existing proxy. In every layout, keep `7576`, `7578`, and `5037` off the public Internet.
