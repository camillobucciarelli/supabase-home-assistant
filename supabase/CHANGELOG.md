# Changelog

## 0.1.6

- Generate Supabase `sb_publishable` and `sb_secret` API keys during bootstrap.
- Enable Supabase's asymmetric JWT key configuration when the upstream helper is available.
- Install Node.js in the add-on image so Supabase's key generation helper can run locally.

## 0.1.5

- Stop reserving port `8000` from the Home Assistant add-on container.
- Configure Supabase Kong to publish the selected `public_port` directly.

## 0.1.4

- Run Docker Compose from the generated Supabase project directory so relative `COMPOSE_FILE` entries resolve correctly.

## 0.1.3

- Resolve the current add-on container by Docker hostname/name when `HOSTNAME` is not directly inspectable.

## 0.1.2

- Add `public_url` for HTTPS/reverse-proxy deployments such as Cloudflare Tunnel.
- Document Cloudflare Tunnel configuration.

## 0.1.1

- Detect Docker socket at either `/var/run/docker.sock` or `/run/docker.sock`.
- Add a clear startup error when Protection mode prevents Docker socket access.
- Use the host Docker socket path for the generated Supabase Compose configuration.

## 0.1.0

- Initial Home Assistant add-on repository.
- Fetches the official Supabase Docker self-hosting configuration.
- Starts and manages the Supabase Compose stack through Supervisor Docker API access.
