-- Full request history for one user (compliance / "what did this person do" view).
-- Edit the WHERE clause to target the user_id you want.
--
-- Note: prompt is in proxy_server_request->'messages', NOT the 'messages' column.
-- (LiteLLM's 'messages' column is only populated for realtime API calls.)
-- Both fields require store_prompts_in_spend_logs=true in config.yaml.
SELECT
  "startTime"::timestamp(0) AS ts,
  model,
  prompt_tokens,
  completion_tokens,
  ROUND(spend::numeric, 6) AS spend_usd,
  status,
  -- First user message in the request (truncated for readability)
  LEFT(
    proxy_server_request->'messages'->-1->>'content',
    120
  ) AS last_user_msg,
  -- Model's response content
  LEFT(
    response->'choices'->0->'message'->>'content',
    120
  ) AS response_preview
FROM "LiteLLM_SpendLogs"
WHERE "user" = 'test@example.com'    -- <<< change this
ORDER BY "startTime" DESC
LIMIT 50;
