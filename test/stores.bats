#!/usr/bin/env bats

load test_helper

@test "list shows global store by default" {
  run "$ENGRAM" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"global"* ]]
}

@test "create a store" {
  run "$ENGRAM" create teststore
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created store"* ]]
}

@test "list shows created store" {
  "$ENGRAM" create teststore 2> /dev/null
  run "$ENGRAM" list
  [[ "$output" == *"teststore"* ]]
}

@test "create duplicate store reports error" {
  "$ENGRAM" create teststore 2> /dev/null
  run "$ENGRAM" create teststore
  [[ "$output" == *"already exists"* ]]
}

@test "remove a store" {
  "$ENGRAM" create teststore 2> /dev/null
  echo y | "$ENGRAM" remove teststore 2> /dev/null

  run "$ENGRAM" list
  [[ "$output" != *"teststore"* ]]
}

@test "remove nonexistent store fails" {
  run "$ENGRAM" remove nosuchstore
  [ "$status" -ne 0 ]
}

@test "create rejects names with special characters" {
  run "$ENGRAM" create "bad@name"
  [[ "$output" == *"may only contain"* ]]
}

@test "create accepts hyphens and underscores" {
  run "$ENGRAM" create "my-test_store"
  [ "$status" -eq 0 ]
}
