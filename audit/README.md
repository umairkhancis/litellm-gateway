# Audit Queries

LiteLLM auto-populates `LiteLLM_SpendLogs` on every request. This directory contains
ready-to-run SQL for common operator and compliance views — no separate audit
table or custom code required.

## Schema reference (the columns you care about)

| Column | Meaning |
|---|---|
| `request_id` | Unique per request (= OpenAI's chatcmpl- ID) |
| `"user"` | LiteLLM user_id — populated from SSO identity |
| `team_id` | Team membership at request time |
| `api_key` | **Hashed** virtual key (not the raw key) |
| `model` | The upstream model that actually served the call |
| `custom_llm_provider` | `anthropic`, `openai`, etc. |
| `prompt_tokens` / `completion_tokens` / `total_tokens` | Usage |
| `spend` | USD cost |
| `request_duration_ms` | End-to-end latency including upstream |
| `status` | `success` or `failure` |
| `cache_hit` | `True` / `False` |
| `proxy_server_request` | Full raw HTTP request — **prompt lives here** at `proxy_server_request->'body'->'messages'` (when `store_prompts_in_spend_logs: true`) |
| `response` | Full completion JSONB (when `store_prompts_in_spend_logs: true`) |
| `messages` | **Realtime API only.** Empty `{}` for `/v1/chat/completions`. Use `proxy_server_request` instead. |
| `requester_ip_address` | Source IP |
| `"startTime"` | When the request landed |

## Running queries

```bash
# Inline:
docker compose exec -T postgres psql -U litellm -d litellm -c "$(cat audit/queries/<file>.sql)"

# Or interactive:
docker compose exec postgres psql -U litellm -d litellm
litellm=> \i /tmp/q.sql       # if you copy a query file in
```

## Privacy / retention

- `store_prompts_in_spend_logs: true` in `config.yaml` controls content storage.
  Disable for privacy-sensitive deployments.
- No automatic retention policy — set up `pg_cron` or equivalent if you need
  to expire rows older than N days for compliance.
- The `api_key` column is a hash (sha256), not the raw key. Safe to expose in
  internal dashboards.
