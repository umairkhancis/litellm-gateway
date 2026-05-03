# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A self-hosted LiteLLM proxy gateway. It unifies Anthropic cloud models and local LLM runtimes behind a single OpenAI-compatible API. It is one app in a broader `ai-infra/` workspace that models enterprise prod topology.

Stack (this repo): LiteLLM + Postgres + Redis

Shared infra (sibling folders, bring up first):
- `../idp/` — Dex OIDC IdP (stands in for Okta)
- `../gateway/` — Caddy reverse proxy (stands in for shared internal LB / ALB)

## Starting and stopping

```bash
# One-time setup (first time only)
docker network create infra-net

# Bring up shared infra first
cd ../idp     && docker compose up -d
cd ../gateway && docker compose up -d

# Then bring up this app
docker compose up -d

# Reload LiteLLM config after editing config.yaml (no full restart needed)
docker compose restart litellm

# Tear down (keeps volumes)
docker compose down

# Tear down and wipe all data
docker compose down -v
```

## Environment setup

Copy `.env.example` to `.env` and fill in:
- `LITELLM_MASTER_KEY` — admin key, prefix with `sk-`, generate with `openssl rand -hex 32`
- `POSTGRES_PASSWORD` — generate with `openssl rand -hex 24`
- `ANTHROPIC_API_KEY` — required for cloud models
- OIDC vars (`GENERIC_CLIENT_ID`, etc.) — point at your IdP; for local Dex use `https://dex.umairkhancis.test`

## Architecture

```
Browser / API clients
       │
   Caddy :443  (../gateway — shared internal LB, stands in for ALB)
       │                    aliases: litellm.umairkhancis.test, dex.umairkhancis.test
       │
  ┌────┴────────────────────────────────────────────────────┐
  │                      infra-net (shared Docker network)  │
  │  litellm :4000                 Dex :5556 (../idp)       │
  │  (admin UI + API)              OIDC IdP, stands in      │
  └────┬──────┬──────────────────  for Okta ────────────────┘
       │      │
   Postgres  Redis    ← default network (private subnet)
   (spend,   (response   invisible to other apps
    keys,     cache)
    users)
```

Network boundaries:
- `infra-net` — shared subnet; litellm, caddy, dex all join it
- `litellm-gateway_default` — private subnet; postgres and redis only, not reachable from other apps
- litellm joins both networks; postgres/redis join only the private one

Traffic:
- Browser → Caddy: HTTPS (mkcert cert in `../certs/`)
- Caddy → litellm: plain HTTP (inside network, like ALB → app)
- litellm → Dex: HTTPS via `dex.umairkhancis.test` (simulates calling external SaaS IdP)
- litellm → postgres/redis: plain TCP (private subnet)

## Configuration files

| File | Purpose |
|---|---|
| `config.yaml` | Model list, LiteLLM settings, spend/cache config |
| `caddy/litellm.caddy` | This app's routing snippet — registered into `../gateway/` |
| `docker-compose.yml` | Service definitions (litellm, postgres, redis) |
| `.env` / `.env.example` | Secrets and provider keys |
| `../gateway/docker-compose.yml` | Caddy — add a volume mount here to register a new app |
| `../idp/dex/config.yaml` | Dex — add a staticClient here to onboard a new app's OIDC |
| `../certs/` | mkcert TLS certs (shared, not in git) |

## Model routing

`config.yaml` defines the model list. Cloud models use `ANTHROPIC_API_KEY`. Local models point at a runtime via `api_base`. The active local runtime is indicated by comments in the local model block (e.g., `# DMR`).

**Default runtime: DMR (Docker Model Runner)** — zero setup, built into Docker Desktop.

To switch runtimes (DMR → Ollama → llama.cpp → vLLM), follow `SWAP_RUNTIME_LAYER.md`. The steps are: stop old runtime, edit the local model block in `config.yaml`, start new runtime, then `docker compose restart litellm`.

The `claude-*` wildcard entry in `config.yaml` passes any unrecognized `claude-` model name straight through to Anthropic, so new Claude model IDs work without config changes.

## Auth model

- **Admin UI (`/ui`)**: gated by OIDC SSO. LiteLLM creates user records on first login.
- **API paths (`/v1/*`, `/chat/*`, etc.)**: authenticated by virtual keys issued by LiteLLM.
- New users auto-get `internal_user` role, $5 / 30-day budget (`default_internal_user_params` in `config.yaml`).
- Both `proxy_admin` and `internal_user` roles can generate personal keys.

## Onboarding a new app to the shared infra

1. **IdP** — add a `staticClient` entry to `../idp/dex/config.yaml`, then `docker compose restart dex` in `../idp/`
2. **Gateway** — add a volume mount for the new app's `.caddy` snippet in `../gateway/docker-compose.yml`, then `docker compose restart caddy` in `../gateway/`
3. **Network** — ensure the new app's compose joins `infra-net` as an external network

## Spend queries

LiteLLM writes every request to `LiteLLM_SpendLogs` automatically.

```bash
# Inline
docker compose exec -T postgres psql -U litellm -d litellm -c "SELECT model, COUNT(*), SUM(spend) FROM \"LiteLLM_SpendLogs\" GROUP BY model;"

# Interactive psql
docker compose exec postgres psql -U litellm -d litellm
```

`store_prompts_in_spend_logs: true` in `config.yaml` means full prompt/response JSON is stored. Disable for privacy-sensitive deployments.

## TLS certs

Certs live in `../certs/` (shared across all infra, generated by mkcert, not in git). `cacert.pem` is the bundle (mkcert root + public CAs) mounted into the litellm container so Anthropic API calls still validate. Regenerate with mkcert if certs expire.
