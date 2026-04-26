-- Model usage breakdown. Tells you which models are actually getting traffic
-- (so you know what to keep, retire, or negotiate volume pricing on).
SELECT
  model,
  custom_llm_provider AS provider,
  COUNT(*) AS requests,
  COUNT(DISTINCT "user") AS unique_users,
  SUM(total_tokens) AS total_tokens,
  ROUND(SUM(spend)::numeric, 4) AS spend_usd,
  ROUND(AVG(request_duration_ms)::numeric, 0) AS avg_latency_ms,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'failure') / NULLIF(COUNT(*), 0), 2) AS failure_pct
FROM "LiteLLM_SpendLogs"
WHERE "startTime" > NOW() - INTERVAL '7 days'
GROUP BY model, custom_llm_provider
ORDER BY spend_usd DESC NULLS LAST;
