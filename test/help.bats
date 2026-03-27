#!/usr/bin/env bats

load test_helper

@test "help exits 0" {
  run "$ENGRAM" --help
  [ "$status" -eq 0 ]
}

@test "help shows SYNOPSIS" {
  run "$ENGRAM" --help
  [[ "$output" == *"SYNOPSIS"* ]]
}

@test "no args shows help and exits 1" {
  run "$ENGRAM"
  [ "$status" -eq 1 ]
}
