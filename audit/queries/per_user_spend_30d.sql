-- Per-user spend over the last 30 days. Operator's primary cost-attribution view.
SELECT
  "user" AS user_id,
  team_id,
  COUNT(*) AS requests,
  SUM(prompt_tokens) AS prompt_tokens,
  SUM(completion_tokens) AS completion_tokens,
  ROUND(SUM(spend)::numeric, 4) AS spend_usd,
  ROUND(AVG(request_duration_ms)::numeric, 0) AS avg_latency_ms,
  COUNT(*) FILTER (WHERE status = 'failure') AS failures
FROM "LiteLLM_SpendLogs"
WHERE "startTime" > NOW() - INTERVAL '30 days'
GROUP BY "user", team_id
ORDER BY spend_usd DESC NULLS LAST;
