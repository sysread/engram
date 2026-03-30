#!/usr/bin/env bats

load test_helper

@test "setup creates .mcp.json, .claude/, and .gitignore in a git repo" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  printf 'teststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  [ -f "$project_dir/.mcp.json" ]
  [ -f "$project_dir/.claude/CLAUDE.md" ]
  [ -f "$project_dir/.claude/settings.local.json" ]
  [ -f "$project_dir/.gitignore" ]

  # .mcp.json contains engram entry
  [[ "$(cat "$project_dir/.mcp.json")" == *"engram"* ]]

  # .gitignore contains both entries
  [[ "$(cat "$project_dir/.gitignore")" == *".mcp.json"* ]]
  [[ "$(cat "$project_dir/.gitignore")" == *".claude/"* ]]

  # settings.local.json has hooks and permission
  [[ "$(cat "$project_dir/.claude/settings.local.json")" == *"SessionStart"* ]]
  [[ "$(cat "$project_dir/.claude/settings.local.json")" == *"mcp__engram"* ]]

  rm -rf "$project_dir"
}

@test "setup is idempotent in a git repo" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  printf 'teststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  # Run again - should show skip for configured items
  run bash -c "cd '$project_dir' && printf 'teststore\nn\n' | '$ENGRAM' setup"
  [[ "$output" == *"skip (already configured)"* ]]
  [[ "$output" == *"skip (already ignored)"* ]]

  rm -rf "$project_dir"
}

@test "setup skips .gitignore outside a git repo" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  printf 'teststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  [ -f "$project_dir/.mcp.json" ]
  [ -f "$project_dir/.claude/CLAUDE.md" ]
  [ ! -f "$project_dir/.gitignore" ]

  rm -rf "$project_dir"
}

@test "setup detects complex .gitignore patterns" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  # Write a complex .gitignore that already covers .claude/ and .mcp.json
  # via glob patterns rather than exact entries
  cat > .gitignore <<'GITIGNORE'
**/.claude/
!/.claude/
/.claude/*
!/.claude/skills/
.mcp.json
GITIGNORE

  printf 'teststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  # .gitignore should not have been modified (entries already ignored)
  run bash -c "cd '$project_dir' && printf 'teststore\nn\n' | '$ENGRAM' setup"
  [[ "$output" == *"skip (already ignored)"* ]]

  rm -rf "$project_dir"
}

@test "setup with NEW creates a new store" {
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  printf 'NEW\nbrandnew\ny\n' | "$ENGRAM" setup 2> /dev/null

  # Verify store was created
  run "$ENGRAM" list
  [[ "$output" == *"brandnew"* ]]

  # Verify .mcp.json references the new store
  [[ "$(cat "$project_dir/.mcp.json")" == *"brandnew"* ]]

  rm -rf "$project_dir"
}
