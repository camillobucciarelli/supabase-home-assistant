# Changelog

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
