# Supabase Add-on Documentation

This add-on bootstraps the official Supabase self-hosting Docker Compose configuration and starts it through the Home Assistant Supervisor Docker daemon.

Supabase's official documentation recommends Docker for self-hosting, with at least 4 GB RAM, 2 CPU cores, and 40 GB SSD for the full stack. It also requires you to manage security updates, configuration, backups, Postgres maintenance, and uptime.

## Configuration

- `public_url`: external URL used by browsers and clients. For Cloudflare Tunnel, use the HTTPS public hostname, for example `https://supabase.example.com`.
- `public_host`: local host name or IP used in logs for the Home Assistant host.
- `public_port`: local host port published by the Supabase Kong container for the API gateway and Studio.
- `site_url`: default Auth redirect URL.
- `dashboard_username`: HTTP basic auth username for Studio.
- `dashboard_password`: HTTP basic auth password for Studio. If empty, a random password is generated and written to the generated `.env`.
- `postgres_password`: Postgres password. If empty, a random password is generated and written to the generated `.env`.
- `supabase_ref`: git ref fetched from `https://github.com/supabase/supabase`. Use `master` for the current upstream compose files or pin a commit/tag for reproducibility.
- `enable_analytics`: enables Supabase Logs & Analytics through the upstream `run.sh config add logs` helper.
- `recreate_on_start`: force-recreates containers on each add-on start.
- `stop_stack_on_addon_stop`: stops the Supabase stack when the add-on stops.

## Ports

The add-on itself does not publish Home Assistant add-on ports. Supabase's Kong container publishes `public_port` directly on the Home Assistant Docker host. This avoids a port conflict between the add-on container and the Supabase Kong container.

## Cloudflare Tunnel

Use these add-on options:

```yaml
public_url: https://supabase.example.com
public_host: homeassistant.local
public_port: 8000
site_url: https://supabase.example.com
```

Configure the Cloudflare Tunnel public hostname to forward to the local service:

```text
https://supabase.example.com -> http://homeassistant.local:8000
```

If your tunnel runs outside the Home Assistant host, replace `homeassistant.local` with the Home Assistant machine IP address, for example `http://192.168.1.50:8000`.

## Data

Runtime files are stored below the add-on `/data` mount:

- `/data/supabase/source`: sparse checkout of the upstream Supabase repository.
- `/data/supabase/project`: generated Supabase Docker Compose project and `.env`.
- `/data/supabase/project/volumes`: database, storage, and service data.

## Operations

The add-on logs `docker compose ps` every 60 seconds. If you need to inspect the generated credentials, open the add-on terminal or SSH into the host and inspect the generated `.env` inside the add-on data directory.

## API keys and Auth signing

On first bootstrap with a current Supabase `supabase_ref`, the add-on runs Supabase's `utils/add-new-auth-keys.sh --update-env` helper after the legacy key generator. This writes the new `SUPABASE_PUBLISHABLE_KEY` and `SUPABASE_SECRET_KEY` values to the generated `.env`, enables `JWT_KEYS` for Auth, and configures `JWT_JWKS` for PostgREST, Realtime, and Storage.

Use `SUPABASE_PUBLISHABLE_KEY` for browser/client code instead of the legacy `ANON_KEY`. Use `SUPABASE_SECRET_KEY` only in trusted server-side code instead of the legacy `SERVICE_ROLE_KEY`.

The add-on checks for these generated values on startup and does not regenerate them if they already exist. Regenerating the asymmetric key pair invalidates ES256 user sessions, so rotate intentionally with Supabase's upstream helper inside `/data/supabase/project` when needed.

Because this add-on needs `docker_api: true`, Home Assistant must run it with **Protection mode disabled**. If Protection mode is enabled, the Docker socket is not mounted and startup fails with an error similar to:

```text
failed to connect to the docker API at unix:///var/run/docker.sock
```

To disable Protection mode:

1. Stop the add-on.
2. Open **Settings > Add-ons** or **Settings > Apps**, depending on your Home Assistant version.
3. Open **Supabase > Info**.
4. Turn off **Protection mode**.
5. Start the add-on again.

Recent Home Assistant versions are removing the old **Advanced mode** user-profile toggle. If the Protection mode switch is still not visible in the UI, disable it through the Supervisor API or Home Assistant CLI from the host.

For production use, put Supabase behind HTTPS and configure backups before storing important data.

## Limitations

Home Assistant add-ons are single supervised containers. Supabase is a multi-container stack, so this add-on requires `docker_api: true` and creates additional Docker containers on the Home Assistant host.

Ingress is not enabled because Supabase's gateway and Studio are started in external Supabase containers, not inside the add-on container itself.
