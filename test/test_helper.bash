ENGRAM="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/engram"

setup() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  export ENGRAM_DATA_DIR="$tmpdir"
}

teardown() {
  rm -rf "$ENGRAM_DATA_DIR"
}
