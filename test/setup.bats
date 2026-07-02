#!/usr/bin/env bats

load test_helper

@test "setup creates .mcp.json, .claude/, and .gitignore for Claude Code" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  printf '1\nteststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  [ -f "$project_dir/.mcp.json" ]
  [ -f "$project_dir/.claude/CLAUDE.md" ]
  [ -f "$project_dir/.claude/settings.local.json" ]
  [ -f "$project_dir/.gitignore" ]

  # .mcp.json contains engram entry
  [[ "$(cat "$project_dir/.mcp.json")" == *"engram"* ]]

  # .gitignore contains relevant entries
  [[ "$(cat "$project_dir/.gitignore")" == *".mcp.json"* ]]
  [[ "$(cat "$project_dir/.gitignore")" == *".claude/"* ]]

  # settings.local.json has hooks and permission
  [[ "$(cat "$project_dir/.claude/settings.local.json")" == *"SessionStart"* ]]
  [[ "$(cat "$project_dir/.claude/settings.local.json")" == *"mcp__engram"* ]]

  rm -rf "$project_dir"
}

@test "setup is idempotent for Claude Code" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  printf '1\nteststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  # Run again - should show skip for configured items
  run bash -c "cd '$project_dir' && printf '1\nteststore\nn\n' | '$ENGRAM' setup"
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
  printf '1\nteststore\ny\n' | "$ENGRAM" setup 2> /dev/null

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

  printf '1\nteststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  # .gitignore should not have been modified (entries already ignored)
  run bash -c "cd '$project_dir' && printf '1\nteststore\nn\n' | '$ENGRAM' setup"
  [[ "$output" == *"skip (already ignored)"* ]]

  rm -rf "$project_dir"
}

@test "setup with NEW creates a new store" {
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  printf '1\nNEW\nbrandnew\ny\n' | "$ENGRAM" setup 2> /dev/null

  # Verify store was created
  run "$ENGRAM" list-stores
  [[ "$output" == *"brandnew"* ]]

  # Verify .mcp.json references the new store
  [[ "$(cat "$project_dir/.mcp.json")" == *"brandnew"* ]]

  rm -rf "$project_dir"
}

@test "setup creates opencode.json and .opencode/instructions/engram.md" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  printf '3\nteststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  [ -f "$project_dir/opencode.json" ]
  [ -f "$project_dir/.opencode/instructions/engram.md" ]
  [ -f "$project_dir/.gitignore" ]

  # opencode.json contains engram MCP entry
  [[ "$(cat "$project_dir/opencode.json")" == *"engram"* ]]
  [[ "$(cat "$project_dir/opencode.json")" == *"\"type\": \"local\""* ]]

  # opencode.json has instructions pointing to the engram instructions file
  [[ "$(cat "$project_dir/opencode.json")" == *".opencode/instructions/engram.md"* ]]

  # Instructions file contains engram content
  [[ "$(cat "$project_dir/.opencode/instructions/engram.md")" == *"engram_remember"* ]]

  # .gitignore contains opencode entries
  [[ "$(cat "$project_dir/.gitignore")" == *"opencode.json"* ]]
  [[ "$(cat "$project_dir/.gitignore")" == *".opencode/"* ]]

  rm -rf "$project_dir"
}

@test "setup opencode is idempotent" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  printf '3\nteststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  # Run again - should show skip for configured items
  run bash -c "cd '$project_dir' && printf '3\nteststore\nn\n' | '$ENGRAM' setup"
  [[ "$output" == *"skip (already configured)"* ]]

  rm -rf "$project_dir"
}

@test "setup opencode updates existing opencode.json" {
  "$ENGRAM" create teststore 2> /dev/null
  "$ENGRAM" create global 2> /dev/null

  local project_dir
  project_dir="$(mktemp -d)"

  cd "$project_dir"
  git init -q

  # Pre-create opencode.json with other config keys
  printf '{"lsp": true, "compaction": {"auto": false}}' > "$project_dir/opencode.json"

  printf '3\nteststore\ny\n' | "$ENGRAM" setup 2> /dev/null

  # Existing keys are preserved
  [[ "$(cat "$project_dir/opencode.json")" == *"\"lsp\": true"* ]]
  [[ "$(cat "$project_dir/opencode.json")" == *"\"auto\": false"* ]]

  # New MCP entry is added
  [[ "$(cat "$project_dir/opencode.json")" == *"engram"* ]]
  [[ "$(cat "$project_dir/opencode.json")" == *"\"type\": \"local\""* ]]

  rm -rf "$project_dir"
}
