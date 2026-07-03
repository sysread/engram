#!/usr/bin/env bats

load test_helper

@test "init creates store and registers in projects.json" {
  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  run "$ENGRAM" init testproject

  [ "$status" -eq 0 ]
  [[ "$output" == *"registered for"* ]]

  # Store was created
  run "$ENGRAM" list-stores
  [[ "$output" == *"testproject"* ]]

  # projects.json contains the canonical repo path
  local canonical
  canonical="$(cd "$project_dir" && git rev-parse --git-common-dir)"
  canonical="$(cd "$canonical/.." && pwd -P)"
  [[ "$(cat "$ENGRAM_PROJECTS_PATH")" == *"\"$canonical\""* ]]
  [[ "$(cat "$ENGRAM_PROJECTS_PATH")" == *"\"testproject\""* ]]
  [[ "$(cat "$ENGRAM_PROJECTS_PATH")" == *"\"global\""* ]]

  rm -rf "$project_dir"
}

@test "init is idempotent" {
  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  run "$ENGRAM" init testproject
  [ "$status" -eq 0 ]

  # Run again - should succeed without error
  run "$ENGRAM" init testproject
  [ "$status" -eq 0 ]
  [[ "$output" == *"registered for"* ]]

  local canonical
  canonical="$(cd "$project_dir" && git rev-parse --git-common-dir)"
  canonical="$(cd "$canonical/.." && pwd -P)"
  local count
  count="$(jq --arg c "$canonical" '.[$c] | length' "$ENGRAM_PROJECTS_PATH")"
  [ "$count" -eq 2 ]  # testproject + global

  rm -rf "$project_dir"
}

@test "init resolves canonical repo path from worktree" {
  if git worktree --help &>/dev/null; then
    local main_dir
    main_dir="$(mktemp -d)"

    cd "$main_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    git commit --allow-empty -m "initial" 2>/dev/null

    local wt_dir
    wt_dir="$(mktemp -d)"
    git worktree add "$wt_dir" HEAD 2>/dev/null || true

    if [ -d "$wt_dir/.git" ]; then
      cd "$wt_dir"

      run "$ENGRAM" init wtproject
      [ "$status" -eq 0 ]

      # projects.json key should be the main repo, not the worktree
      [[ "$(cat "$ENGRAM_PROJECTS_PATH")" != *"$wt_dir"* ]]
      [ -n "$(cat "$ENGRAM_PROJECTS_PATH")" ]

      git worktree remove "$wt_dir" 2>/dev/null || rm -rf "$wt_dir"
    fi

    rm -rf "$main_dir"
  else
    skip "git worktree not available"
  fi
}

@test "init outside a git repo uses CWD" {
  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"

  run "$ENGRAM" init nonrepo
  [ "$status" -eq 0 ]

  local resolved
  resolved="$(cd "$project_dir" && pwd -P)"
  [[ "$(cat "$ENGRAM_PROJECTS_PATH")" == *"\"$resolved\""* ]]

  rm -rf "$project_dir"
}

@test "init validates store name" {
  run "$ENGRAM" init "bad/name"
  [ "$status" -eq 1 ]
}

@test "init --claude writes .mcp.json" {
  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  run "$ENGRAM" init --claude testproject
  [ "$status" -eq 0 ]
  [[ "$output" == *"registered for"* ]]
  [[ "$output" == *"Wrote MCP config"* ]]

  # .mcp.json was created
  [ -f "$project_dir/.mcp.json" ]
  [[ "$(cat "$project_dir/.mcp.json")" == *"engram"* ]]
  [[ "$(cat "$project_dir/.mcp.json")" == *"\"type\": \"stdio\""* ]]
  # No store args in the command - auto-discovery
  [[ "$(cat "$project_dir/.mcp.json")" == *"\"mcp\""* ]]

  rm -rf "$project_dir"
}

@test "init --opencode writes opencode.json and merges existing" {
  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  # Pre-create opencode.json with other keys
  printf '{"lsp": true, "compaction": {"auto": false}}' > "$project_dir/opencode.json"

  run "$ENGRAM" init --opencode testproject
  [ "$status" -eq 0 ]

  # Existing keys are preserved
  [[ "$(cat "$project_dir/opencode.json")" == *"\"lsp\": true"* ]]
  [[ "$(cat "$project_dir/opencode.json")" == *"\"auto\": false"* ]]

  # MCP entry was added
  [[ "$(cat "$project_dir/opencode.json")" == *"engram"* ]]
  [[ "$(cat "$project_dir/opencode.json")" == *"\"type\": \"local\""* ]]
  [[ "$(cat "$project_dir/opencode.json")" == *"\"enabled\": true"* ]]

  rm -rf "$project_dir"
}

@test "init --claude --global writes to ~/.claude/.mcp.json" {
  "$ENGRAM" create testproject 2> /dev/null

  local test_home
  test_home="$(mktemp -d)"
  export HOME="$test_home"

  run "$ENGRAM" init --claude --global testproject
  [ "$status" -eq 0 ]

  [ -f "$test_home/.claude/.mcp.json" ]
  [[ "$(cat "$test_home/.claude/.mcp.json")" == *"engram"* ]]
  [[ "$(cat "$test_home/.claude/.mcp.json")" == *"\"type\": \"stdio\""* ]]

  rm -rf "$test_home"
}

@test "init --opencode --global writes to ~/.config/opencode/opencode.jsonc" {
  "$ENGRAM" create testproject 2> /dev/null

  local test_home
  test_home="$(mktemp -d)"
  export HOME="$test_home"

  run "$ENGRAM" init --opencode --global testproject
  [ "$status" -eq 0 ]

  [ -f "$test_home/.config/opencode/opencode.jsonc" ]
  [[ "$(cat "$test_home/.config/opencode/opencode.jsonc")" == *"engram"* ]]
  [[ "$(cat "$test_home/.config/opencode/opencode.jsonc")" == *"\"type\": \"local\""* ]]

  rm -rf "$test_home"
}

@test "mcp auto-discovers stores from projects.json" {
  "$ENGRAM" create teststore 2> /dev/null

  local cwd
  cwd="$(pwd -P)"

  jq -nc --arg dir "$cwd" --argjson stores '["teststore","global"]' \
    '{($dir): $stores}' > "$ENGRAM_PROJECTS_PATH"

  resp="$({
    mcp_init 1
    echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  } | "$ENGRAM" mcp 2>/dev/null | mcp_response_for 2)"

  [ -n "$resp" ]
  [ "$(jq -r '.result.tools[].name' <<< "$resp" | sort | head -1)" = "find-duplicates" ]
}

@test "mcp with empty projects.json fails with helpful message" {
  rm -f "$ENGRAM_PROJECTS_PATH"

  run "$ENGRAM" mcp
  [ "$status" -eq 1 ]
  [[ "$output" == *"No stores configured"* ]]
}
