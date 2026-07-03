#!/usr/bin/env bats

load test_helper

@test "init creates store and registers in projects.json" {
  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  ENGRAM_PROJECTS="$(echo ~/.config/engram/projects.json)"

  # capture existing projects.json (may not exist)
  local saved_projects
  if [ -f "$ENGRAM_PROJECTS" ]; then
    saved_projects="$(cat "$ENGRAM_PROJECTS")"
  fi

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
  [[ "$(cat "$ENGRAM_PROJECTS")" == *"\"$canonical\""* ]]
  [[ "$(cat "$ENGRAM_PROJECTS")" == *"\"testproject\""* ]]
  [[ "$(cat "$ENGRAM_PROJECTS")" == *"\"global\""* ]]

  # restore projects.json
  if [ -n "$saved_projects" ]; then
    echo "$saved_projects" > "$ENGRAM_PROJECTS"
  else
    rm -f "$ENGRAM_PROJECTS"
  fi

  rm -rf "$project_dir"
}

@test "init is idempotent" {
  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  ENGRAM_PROJECTS="$(echo ~/.config/engram/projects.json)"
  local saved_projects
  if [ -f "$ENGRAM_PROJECTS" ]; then
    saved_projects="$(cat "$ENGRAM_PROJECTS")"
  fi

  run "$ENGRAM" init testproject
  [ "$status" -eq 0 ]

  # Run again - should succeed without error
  run "$ENGRAM" init testproject
  [ "$status" -eq 0 ]
  [[ "$output" == *"registered for"* ]]

  # projects.json doesn't have duplicate entries
  local canonical
  canonical="$(cd "$project_dir" && git rev-parse --git-common-dir)"
  canonical="$(cd "$canonical/.." && pwd -P)"
  local count
  count="$(jq --arg c "$canonical" '.[$c] | length' "$ENGRAM_PROJECTS")"
  [ "$count" -eq 2 ]  # testproject + global

  # restore
  if [ -n "$saved_projects" ]; then
    echo "$saved_projects" > "$ENGRAM_PROJECTS"
  else
    rm -f "$ENGRAM_PROJECTS"
  fi

  rm -rf "$project_dir"
}

@test "init resolves canonical repo path from worktree" {
  if git worktree --help &>/dev/null; then
    local main_dir
    main_dir="$(mktemp -d)"

    cd "$main_dir"
    git init -q
    git commit --allow-empty -m "initial" 2>/dev/null

    ENGRAM_PROJECTS="$(echo ~/.config/engram/projects.json)"
    local saved_projects
    if [ -f "$ENGRAM_PROJECTS" ]; then
      saved_projects="$(cat "$ENGRAM_PROJECTS")"
    fi

    # Create a worktree
    local wt_dir
    wt_dir="$(mktemp -d)"
    git worktree add "$wt_dir" HEAD 2>/dev/null || true

    if [ -d "$wt_dir/.git" ]; then
      cd "$wt_dir"

      run "$ENGRAM" init wtproject
      [ "$status" -eq 0 ]

      # projects.json key should be the main repo, not the worktree
      [[ "$(cat "$ENGRAM_PROJECTS")" != *"$wt_dir"* ]]
      [ -n "$(cat "$ENGRAM_PROJECTS")" ]

      git worktree remove "$wt_dir" 2>/dev/null || rm -rf "$wt_dir"
    fi

    # restore
    if [ -n "$saved_projects" ]; then
      echo "$saved_projects" > "$ENGRAM_PROJECTS"
    else
      rm -f "$ENGRAM_PROJECTS"
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

  ENGRAM_PROJECTS="$(echo ~/.config/engram/projects.json)"
  local saved_projects
  if [ -f "$ENGRAM_PROJECTS" ]; then
    saved_projects="$(cat "$ENGRAM_PROJECTS")"
  fi

  run "$ENGRAM" init nonrepo
  [ "$status" -eq 0 ]

  local resolved
  resolved="$(cd "$project_dir" && pwd -P)"
  [[ "$(cat "$ENGRAM_PROJECTS")" == *"\"$resolved\""* ]]

  # restore
  if [ -n "$saved_projects" ]; then
    echo "$saved_projects" > "$ENGRAM_PROJECTS"
  else
    rm -f "$ENGRAM_PROJECTS"
  fi

  rm -rf "$project_dir"
}

@test "init validates store name" {
  run "$ENGRAM" init "bad/name"
  [ "$status" -eq 1 ]
}

@test "mcp auto-discovers stores from projects.json" {
  "$ENGRAM" create teststore 2> /dev/null

  ENGRAM_PROJECTS="$(echo ~/.config/engram/projects.json)"
  local saved_projects
  if [ -f "$ENGRAM_PROJECTS" ]; then
    saved_projects="$(cat "$ENGRAM_PROJECTS")"
  fi

  mkdir -p "$(dirname "$ENGRAM_PROJECTS")"
  local cwd
  cwd="$(pwd -P)"

  # Register current directory
  jq -nc --arg dir "$cwd" --argjson stores '["teststore","global"]' \
    '{($dir): $stores}' > "$ENGRAM_PROJECTS"

  # Start MCP with no args - should auto-discover
  resp="$({
    mcp_init 1
    echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  } | "$ENGRAM" mcp 2>/dev/null | mcp_response_for 2)"

  [ -n "$resp" ]
  [ "$(jq -r '.result.tools[].name' <<< "$resp" | sort | head -1)" = "find-duplicates" ]

  # restore
  if [ -n "$saved_projects" ]; then
    echo "$saved_projects" > "$ENGRAM_PROJECTS"
  else
    rm -f "$ENGRAM_PROJECTS"
  fi
}

@test "mcp with empty projects.json still serves global" {
  ENGRAM_PROJECTS="$(echo ~/.config/engram/projects.json)"
  local saved_projects
  if [ -f "$ENGRAM_PROJECTS" ]; then
    saved_projects="$(cat "$ENGRAM_PROJECTS")"
  fi

  mkdir -p "$(dirname "$ENGRAM_PROJECTS")"
  local cwd
  cwd="$(pwd -P)"

  # Register with only global - no project store
  jq -nc --arg dir "$cwd" --argjson stores '["global"]' \
    '{($dir): $stores}' > "$ENGRAM_PROJECTS"

  resp="$({
    mcp_init 1
    echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  } | "$ENGRAM" mcp 2>/dev/null | mcp_response_for 2)"

  [ -n "$resp" ]
  [ "$(jq -r '.result.tools[].name' <<< "$resp" | sort | head -1)" = "find-duplicates" ]

  # restore
  if [ -n "$saved_projects" ]; then
    echo "$saved_projects" > "$ENGRAM_PROJECTS"
  else
    rm -f "$ENGRAM_PROJECTS"
  fi
}
