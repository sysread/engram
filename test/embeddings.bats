#!/usr/bin/env bats

load test_helper

# Populates a store with a few entries via the MCP server. Uses raw JSON-RPC
# over stdio since there's no CLI write command.
populate_store() {
  local store="$1"

  for label in "first entry" "second entry" "third entry"; do
    "$ENGRAM" mcp "$store" <<EOF
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"remember","arguments":{"label":"$label","content":"This is the $label with some content for testing.","store":"$store"}}}
EOF
  done 2>/dev/null
}

@test "search returns results" {
  "$ENGRAM" create teststore 2>/dev/null
  populate_store teststore

  run "$ENGRAM" search teststore -- "entry"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[teststore]"* ]]
}

@test "search with no matches returns empty" {
  "$ENGRAM" create teststore 2>/dev/null

  run "$ENGRAM" search teststore -- "xyzzy"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No results"* ]]
}

@test "reindex completes successfully" {
  "$ENGRAM" create teststore 2>/dev/null
  populate_store teststore

  run "$ENGRAM" reindex teststore
  [ "$status" -eq 0 ]
  [[ "$output" == *"Reindexing"* ]]
}

@test "duplicates runs on populated store" {
  "$ENGRAM" create teststore 2>/dev/null
  populate_store teststore

  run "$ENGRAM" duplicates teststore
  [ "$status" -eq 0 ]
}
