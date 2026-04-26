-- Recent activity across all users (operator dashboard).
-- Replaces the "tail the logs and grep" workflow with a structured view.
SELECT
  "startTime"::timestamp(0) AS ts,
  "user" AS user_id,
  team_id,
  model,
  custom_llm_provider AS provider,
  prompt_tokens || '/' || completion_tokens AS tokens_in_out,
  ROUND(spend::numeric, 6) AS spend_usd,
  request_duration_ms AS latency_ms,
  status,
  CASE WHEN cache_hit = 'True' THEN 'HIT' ELSE '' END AS cache
FROM "LiteLLM_SpendLogs"
ORDER BY "startTime" DESC
LIMIT 50;
