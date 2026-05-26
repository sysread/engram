ENGRAM="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/engram"

setup() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  export ENGRAM_DATA_DIR="$tmpdir"
}

teardown() {
  rm -rf "$ENGRAM_DATA_DIR"
}

# Sends one or more JSON-RPC lines (read from stdin) to `engram mcp <stores...>`
# and prints the server's stdout. Stderr is discarded. The caller is responsible
# for including an `initialize` message first if the session requires it; this
# helper is transport-only.
#
# Usage:
#   mcp_call store1 [store2 ...] <<EOF
#   {"jsonrpc":"2.0","id":1,"method":"initialize",...}
#   {"jsonrpc":"2.0","id":2,"method":"tools/call",...}
#   EOF
mcp_call() {
  "$ENGRAM" mcp "$@" 2>/dev/null
}

# Extracts the JSON-RPC response with the given id from a stream of
# newline-delimited JSON objects on stdin.
mcp_response_for() {
  local id="$1"
  jq -c --argjson id "$id" 'select(.id == $id)'
}

# Builds a tools/call request for the given tool name and arguments JSON.
mcp_tool_call() {
  local id="$1" name="$2" args="$3"
  jq -nc --argjson id "$id" --arg name "$name" --argjson args "$args" \
    '{jsonrpc:"2.0",id:$id,method:"tools/call",params:{name:$name,arguments:$args}}'
}

# Standard initialize request, parameterized only by id.
mcp_init() {
  local id="${1:-1}"
  jq -nc --argjson id "$id" \
    '{jsonrpc:"2.0",id:$id,method:"initialize",params:{protocolVersion:"2024-11-05",capabilities:{},clientInfo:{name:"test",version:"0.1"}}}'
}
