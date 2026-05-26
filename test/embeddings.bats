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

@test "recall returns results" {
  "$ENGRAM" create teststore 2>/dev/null
  populate_store teststore

  run "$ENGRAM" recall teststore -- "entry"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[teststore]"* ]]
}

@test "recall with no matches returns empty" {
  "$ENGRAM" create teststore 2>/dev/null

  run "$ENGRAM" recall teststore -- "xyzzy"
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

@test "find-duplicates runs on populated store" {
  "$ENGRAM" create teststore 2>/dev/null
  populate_store teststore

  run "$ENGRAM" find-duplicates teststore
  [ "$status" -eq 0 ]
}

@test "find-duplicates emits TSV with three fields per line" {
  "$ENGRAM" create teststore 2>/dev/null
  populate_store teststore

  # Capture stdout separately - bats' `run` merges stderr into $output,
  # which would mask any logger leakage to stderr and conflate noise with
  # data.
  stdout_file="$BATS_TEST_TMPDIR/out"
  "$ENGRAM" find-duplicates teststore > "$stdout_file" 2>/dev/null

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    tabs="${line//[^	]/}"
    [ "${#tabs}" -eq 2 ] || {
      echo "expected 2 tabs, got ${#tabs} in: $line" >&2
      false
    }
  done < "$stdout_file"
}

@test "find-duplicates -H emits header row" {
  "$ENGRAM" create teststore 2>/dev/null
  populate_store teststore

  stdout_file="$BATS_TEST_TMPDIR/out"
  "$ENGRAM" find-duplicates -H teststore > "$stdout_file" 2>/dev/null

  # Header must be the first stdout line regardless of whether any
  # duplicate pairs were found.
  first="$(head -n1 "$stdout_file")"
  [ "$first" = "score	a	b" ]
}

@test "find-duplicates on empty store: stdout empty, notice on stderr, exit 0" {
  "$ENGRAM" create teststore 2>/dev/null

  # Capture stdout and stderr separately. bats' `run` merges them by default.
  stdout_file="$BATS_TEST_TMPDIR/out"
  stderr_file="$BATS_TEST_TMPDIR/err"
  "$ENGRAM" find-duplicates teststore > "$stdout_file" 2> "$stderr_file"
  status=$?

  [ "$status" -eq 0 ]
  [ ! -s "$stdout_file" ]
  grep -q "No unusually similar memories found" "$stderr_file"
}
