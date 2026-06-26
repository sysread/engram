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

@test "move relocates an entry to another store (CLI)" {
  "$ENGRAM" create src_store 2> /dev/null
  "$ENGRAM" create dst_store 2> /dev/null

  # Seed a memory in src_store via MCP, then move it by slug via the CLI.
  remember="$(mcp_tool_call 2 remember '{"label":"portable note","content":"some body","store":"src_store"}')"
  { mcp_init 1; echo "$remember"; } | mcp_call src_store dst_store > /dev/null

  run "$ENGRAM" move src_store dst_store portable-note
  [ "$status" -eq 0 ]
  [[ "$output" == *"[moved] src_store -> dst_store :: portable-note"* ]]

  # Gone from source, present in destination.
  src_list="$("$ENGRAM" list src_store 2> /dev/null)"
  dst_list="$("$ENGRAM" list dst_store 2> /dev/null)"
  [[ "$src_list" != *"portable note"* ]]
  [[ "$dst_list" == *"portable note"* ]]
}

@test "move refuses to overwrite a colliding slug in the destination (CLI)" {
  "$ENGRAM" create src_store 2> /dev/null
  "$ENGRAM" create dst_store 2> /dev/null

  seed_src="$(mcp_tool_call 2 remember '{"label":"dup","content":"src","store":"src_store"}')"
  seed_dst="$(mcp_tool_call 3 remember '{"label":"dup","content":"dst","store":"dst_store"}')"
  { mcp_init 1; echo "$seed_src"; echo "$seed_dst"; } | mcp_call src_store dst_store > /dev/null

  run "$ENGRAM" move src_store dst_store dup
  [[ "$output" == *"refusing to overwrite"* ]]
}

@test "move of a missing slug reports not found (CLI)" {
  "$ENGRAM" create src_store 2> /dev/null
  "$ENGRAM" create dst_store 2> /dev/null

  run "$ENGRAM" move src_store dst_store no-such-slug
  [[ "$output" == *"Not found in 'src_store'"* ]]
}
