#!/usr/bin/env bats

load test_helper

@test "show nonexistent entry reports error" {
  "$ENGRAM" create teststore 2> /dev/null
  run "$ENGRAM" show teststore no-such-slug
  [[ "$output" == *"not found"* ]]
}

@test "dump empty store produces no output on stdout" {
  "$ENGRAM" create teststore 2> /dev/null
  local stdout
  stdout="$("$ENGRAM" dump teststore 2> /dev/null)"
  [ -z "$stdout" ]
}

@test "list <store> shows memory labels in that store" {
  "$ENGRAM" create teststore 2> /dev/null

  # Write a memory via MCP, then list it via CLI.
  remember="$(mcp_tool_call 2 remember '{"label":"alpha","content":"first content","store":"teststore"}')"
  remember2="$(mcp_tool_call 3 remember '{"label":"beta","content":"second content","store":"teststore"}')"
  {
    mcp_init 1
    echo "$remember"
    echo "$remember2"
  } | mcp_call teststore > /dev/null

  stdout_file="$BATS_TEST_TMPDIR/out"
  "$ENGRAM" list teststore > "$stdout_file" 2>/dev/null

  grep -q "alpha" "$stdout_file"
  grep -q "beta" "$stdout_file"
  # Labels should appear with their store scope prefix.
  grep -q "\[teststore\]" "$stdout_file"
}

@test "list on empty store reports notice on stderr with exit 0" {
  "$ENGRAM" create teststore 2> /dev/null

  stdout_file="$BATS_TEST_TMPDIR/out"
  stderr_file="$BATS_TEST_TMPDIR/err"
  "$ENGRAM" list teststore > "$stdout_file" 2> "$stderr_file"
  status=$?

  [ "$status" -eq 0 ]
  [ ! -s "$stdout_file" ]
  grep -q "No memories" "$stderr_file"
}
