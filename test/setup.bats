#!/usr/bin/env bats

load test_helper

@test "setup creates .mcp.json, .claude/, and .gitignore" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
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

@test "setup is idempotent" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  printf 'teststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  # Run again - should show skip for configured items
  run bash -c "printf 'teststore\nn\n' | '$ENGRAM' setup"
  [[ "$output" == *"skip (already configured)"* ]]

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
