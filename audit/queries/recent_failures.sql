-- Recent failed requests with error context. First place to look when a user reports
-- "my key isn't working" or "the model is returning errors."
SELECT
  "startTime"::timestamp(0) AS ts,
  "user" AS user_id,
  model,
  request_duration_ms AS latency_ms,
  -- Error details live in the response JSONB when status='failure'
  COALESCE(response->>'error', response->'error'->>'message', response::text) AS error_summary
FROM "LiteLLM_SpendLogs"
WHERE status = 'failure'
  AND "startTime" > NOW() - INTERVAL '24 hours'
ORDER BY "startTime" DESC
LIMIT 30;
