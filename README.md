# Supabase Home Assistant Add-ons

Home Assistant add-on repository for running a self-hosted Supabase stack.

This repository currently contains one add-on:

- `supabase`: fetches the official Supabase Docker self-hosting configuration and runs it through the Home Assistant Supervisor Docker daemon.

## Important security note

Supabase self-hosting is a multi-container Docker Compose deployment. Home Assistant add-ons run as a single supervised container, so this add-on needs `docker_api: true` to create and manage the Supabase containers next to Home Assistant.

Only install it on a Home Assistant OS or Supervised host you control.

## Installation

1. Push this repository to GitHub or another Git endpoint reachable by Home Assistant.
2. In Home Assistant, open **Settings > Add-ons > Add-on Store > Repositories**.
3. Add the repository URL.
4. Install the **Supabase** add-on.
5. Configure strong passwords before the first start.

See [`supabase/DOCS.md`](supabase/DOCS.md) for runtime options and operational notes.
