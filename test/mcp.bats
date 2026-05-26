#!/usr/bin/env bats

# JSON-RPC protocol tests for the engram MCP server. These exercise the wire
# protocol directly rather than going through a Claude/Cursor client, so we can
# pin behavior at the layer where regressions have actually shipped (missing
# ping handler, Latin-1 IO corruption).

load test_helper

# ---------------------------------------------------------------------------
# Protocol-level tests (no embeddings, fast)
# ---------------------------------------------------------------------------

@test "mcp initialize returns serverInfo and protocolVersion" {
  "$ENGRAM" create teststore 2>/dev/null

  resp="$(mcp_init 1 | mcp_call teststore | mcp_response_for 1)"

  [ "$(jq -r '.result.serverInfo.name' <<< "$resp")" = "engram" ]
  [ "$(jq -r '.result.protocolVersion' <<< "$resp")" = "2024-11-05" ]
}

@test "mcp ping returns empty result" {
  # Regression guard: an earlier release crashed on Cursor's keepalive pings
  # because there was no clause for the "ping" method. The crash manifested as
  # ~5min reconnect cycles in client logs.
  "$ENGRAM" create teststore 2>/dev/null

  resp="$({
    mcp_init 1
    echo '{"jsonrpc":"2.0","id":2,"method":"ping"}'
  } | mcp_call teststore | mcp_response_for 2)"

  [ "$(jq -r '.result' <<< "$resp")" = "{}" ]
  # Must not be an error response
  [ "$(jq 'has("error")' <<< "$resp")" = "false" ]
}

@test "mcp unknown method returns -32601 instead of crashing" {
  "$ENGRAM" create teststore 2>/dev/null

  resp="$({
    mcp_init 1
    echo '{"jsonrpc":"2.0","id":2,"method":"definitely/not/a/method"}'
  } | mcp_call teststore | mcp_response_for 2)"

  [ "$(jq -r '.error.code' <<< "$resp")" = "-32601" ]
}

@test "mcp tools/list includes the documented tools" {
  "$ENGRAM" create teststore 2>/dev/null

  resp="$({
    mcp_init 1
    echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  } | mcp_call teststore | mcp_response_for 2)"

  names="$(jq -r '.result.tools[].name' <<< "$resp" | sort | tr '\n' ' ')"
  # All seven tools must be present. Order is sorted for stability.
  [ "$names" = "find-duplicates forget list list-stores recall remember show " ]
}

@test "mcp tools/call with unknown tool name returns JSON-RPC error" {
  "$ENGRAM" create teststore 2>/dev/null

  resp="$({
    mcp_init 1
    echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}'
  } | mcp_call teststore | mcp_response_for 2)"

  # Unknown tool -> JSON-RPC invalid params error, not a successful tool_error
  # envelope. Distinction matters for clients that distinguish protocol-level
  # failures from tool-level failures.
  [ "$(jq 'has("error")' <<< "$resp")" = "true" ]
}

# ---------------------------------------------------------------------------
# Round-trip tests (require embeddings; slower)
# ---------------------------------------------------------------------------

@test "mcp remember + recall round-trips non-ASCII content" {
  # Regression guard: BEAM in Latin-1 IO mode corrupts non-ASCII bytes in JSON
  # output, breaking the MCP wire format. The script forces UTF-8 IO at
  # startup; this test ensures that stays true. Includes em-dash (U+2014)
  # which was the actual character that broke production.
  "$ENGRAM" create teststore 2>/dev/null

  content='Unicode round-trip — em-dash, emoji 🧠, and Greek λ.'
  remember="$(mcp_tool_call 2 remember "$(jq -nc --arg s teststore --arg c "$content" \
    '{label:"unicode-test",content:$c,store:$s}')")"
  recall="$(mcp_tool_call 3 recall \
    '{"query":"unicode round-trip em-dash"}')"

  resp="$({
    mcp_init 1
    echo "$remember"
    echo "$recall"
  } | mcp_call teststore | mcp_response_for 3)"

  text="$(jq -r '.result.content[0].text' <<< "$resp")"
  [[ "$text" == *"em-dash"* ]]
  [[ "$text" == *"🧠"* ]]
  [[ "$text" == *"λ"* ]]
}

@test "mcp recall finds a remembered memory by semantic match" {
  "$ENGRAM" create teststore 2>/dev/null

  remember="$(mcp_tool_call 2 remember '{"label":"db-pref","content":"The user prefers Postgres for transactional workloads.","store":"teststore"}')"
  recall="$(mcp_tool_call 3 recall '{"query":"which database does the user like?"}')"

  resp="$({
    mcp_init 1
    echo "$remember"
    echo "$recall"
  } | mcp_call teststore | mcp_response_for 3)"

  text="$(jq -r '.result.content[0].text' <<< "$resp")"
  [[ "$text" == *"Postgres"* ]]
}

@test "mcp show returns full content by exact label" {
  "$ENGRAM" create teststore 2>/dev/null

  remember="$(mcp_tool_call 2 remember '{"label":"specific-thing","content":"Detailed body text only retrievable by exact label.","store":"teststore"}')"
  show="$(mcp_tool_call 3 show '{"label":"specific-thing","store":"teststore"}')"

  resp="$({
    mcp_init 1
    echo "$remember"
    echo "$show"
  } | mcp_call teststore | mcp_response_for 3)"

  text="$(jq -r '.result.content[0].text' <<< "$resp")"
  [[ "$text" == *"specific-thing"* ]]
  [[ "$text" == *"Detailed body text"* ]]
}

@test "mcp show with unknown label returns tool error" {
  "$ENGRAM" create teststore 2>/dev/null

  show="$(mcp_tool_call 2 show '{"label":"never-remembered","store":"teststore"}')"

  resp="$({
    mcp_init 1
    echo "$show"
  } | mcp_call teststore | mcp_response_for 2)"

  # Missing memory is a tool-level error: returned as a normal response with
  # isError:true, not a JSON-RPC error envelope.
  [ "$(jq '.result.isError' <<< "$resp")" = "true" ]
}

@test "mcp recall with branch filter returns branch and unscoped memories" {
  "$ENGRAM" create teststore 2>/dev/null

  # Two memories: one project-wide (no branch), one scoped to "feat-x".
  # A recall with branch=feat-x must include both. A recall with branch=other
  # must include the unscoped one but not the feat-x one.
  unscoped="$(mcp_tool_call 2 remember '{"label":"arch","content":"System uses an event-sourced ledger for billing.","store":"teststore"}')"
  scoped="$(mcp_tool_call 3 remember '{"label":"feat-note","content":"Branch feat-x adds idempotency keys to the ledger writer.","store":"teststore","branch":"feat-x"}')"
  recall_x="$(mcp_tool_call 4 recall '{"query":"ledger billing idempotency","branch":"feat-x"}')"
  recall_other="$(mcp_tool_call 5 recall '{"query":"ledger billing idempotency","branch":"some-other-branch"}')"

  out="$({
    mcp_init 1
    echo "$unscoped"
    echo "$scoped"
    echo "$recall_x"
    echo "$recall_other"
  } | mcp_call teststore)"

  text_x="$(echo "$out" | mcp_response_for 4 | jq -r '.result.content[0].text')"
  text_other="$(echo "$out" | mcp_response_for 5 | jq -r '.result.content[0].text')"

  # feat-x recall sees both
  [[ "$text_x" == *"event-sourced ledger"* ]]
  [[ "$text_x" == *"idempotency keys"* ]]

  # other-branch recall sees only the unscoped one
  [[ "$text_other" == *"event-sourced ledger"* ]]
  [[ "$text_other" != *"idempotency keys"* ]]
}
