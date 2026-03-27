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
