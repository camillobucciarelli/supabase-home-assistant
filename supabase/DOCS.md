# Supabase Add-on Documentation

This add-on bootstraps the official Supabase self-hosting Docker Compose configuration and starts it through the Home Assistant Supervisor Docker daemon.

Supabase's official documentation recommends Docker for self-hosting, with at least 4 GB RAM, 2 CPU cores, and 40 GB SSD for the full stack. It also requires you to manage security updates, configuration, backups, Postgres maintenance, and uptime.

## Configuration

- `public_host`: host name or IP used by browsers and clients.
- `public_port`: host port for the Supabase API gateway and Studio. The add-on exposes container port `8000/tcp`.
- `site_url`: default Auth redirect URL.
- `dashboard_username`: HTTP basic auth username for Studio.
- `dashboard_password`: HTTP basic auth password for Studio. If empty, a random password is generated and written to the generated `.env`.
- `postgres_password`: Postgres password. If empty, a random password is generated and written to the generated `.env`.
- `supabase_ref`: git ref fetched from `https://github.com/supabase/supabase`. Use `master` for the current upstream compose files or pin a commit/tag for reproducibility.
- `enable_analytics`: enables Supabase Logs & Analytics through the upstream `run.sh config add logs` helper.
- `recreate_on_start`: force-recreates containers on each add-on start.
- `stop_stack_on_addon_stop`: stops the Supabase stack when the add-on stops.

## Ports

- `8000/tcp`: Supabase gateway and Studio.
- `5432/tcp`: Supavisor session pooler, disabled by default in Home Assistant port mapping.
- `6543/tcp`: Supavisor transaction pooler, disabled by default in Home Assistant port mapping.

## Data

Runtime files are stored below the add-on `/data` mount:

- `/data/supabase/source`: sparse checkout of the upstream Supabase repository.
- `/data/supabase/project`: generated Supabase Docker Compose project and `.env`.
- `/data/supabase/project/volumes`: database, storage, and service data.

## Operations

The add-on logs `docker compose ps` every 60 seconds. If you need to inspect the generated credentials, open the add-on terminal or SSH into the host and inspect the generated `.env` inside the add-on data directory.

For production use, put Supabase behind HTTPS and configure backups before storing important data.

## Limitations

Home Assistant add-ons are single supervised containers. Supabase is a multi-container stack, so this add-on requires `docker_api: true` and creates additional Docker containers on the Home Assistant host.

Ingress is not enabled because Supabase's gateway and Studio are started in external Supabase containers, not inside the add-on container itself.
