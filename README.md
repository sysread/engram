# engram

A local semantic memory store for LLMs, exposed via MCP over stdio.

`engram` lets AI agents persist and recall information across sessions using semantic search over embeddings.
It uses `SQLite` for storage and `Bumblebee` for local embedding generation.

## Requirements

- Elixir 1.16+
- No other system dependencies

## Quick Start

```bash
# 1. Create a store for your project
./engram create my-project

# 2. Add to Claude Code (see "Configuration" below)

# 3. Claude Code can now use remember, recall, and list tools
```

## Usage

```
engram <command> [options]

Commands:
  list                List existing stores
  create  <name>      Create a new store
  remove  <name>      Remove a store
  reindex <name>      Regenerate all embeddings
  mcp     <name>      Start the MCP server (stdio transport)

Options:
  --help    | -h      Show help
  --verbose | -v      Enable verbose output
```

## Installation

Add the repo directory to your `$PATH`, or symlink the `engram` script into a directory already on your `$PATH`:

```bash
ln -s /path/to/engram/repo/engram ~/bin/engram
```

## Configuration

You can share the same store across multiple worktrees or directories by configuring the MCP server in one of several ways.
The key is to ensure that every instance of claude working on the same project uses the same store name (e.g., `my-project`).

Run `engram --help` to see configuration examples with the correct absolute path to the script already filled in.

### Option A: Project-scoped (shared across worktrees)

Add a `.mcp.json` file to the root of your repository:

```json
{
  "mcpServers": {
    "engram": {
      "type": "stdio",
      "command": "/absolute/path/to/engram",
      "args": ["mcp", "my-project"]
    }
  }
}
```

### Option B: Via `claude mcp add`

```bash
# Project scope -- writes to .mcp.json, shared across worktrees
claude mcp add engram --scope project -- /absolute/path/to/engram mcp my-project

# User scope -- writes to ~/.claude.json, available in all projects
claude mcp add engram --scope user -- /absolute/path/to/engram mcp my-project
```

### Option C: Direct edit of `~/.claude.json`

For per-project configuration outside the repo:

```json
{
  "/path/to/your/project": {
    "mcpServers": {
      "engram": {
        "type": "stdio",
        "command": "/absolute/path/to/engram",
        "args": ["mcp", "my-project"]
      }
    }
  }
}
```

Note: this is keyed by filesystem path.
If you use worktrees, each worktree has a different path and would need its own entry.
Prefer Option A instead.

## Sharing a Store Across Worktrees

The store name (e.g., `my-project`) is what determines which SQLite database engram reads and writes.
Multiple MCP server instances can safely share the same store concurrently -- SQLite handles the locking.

The only thing you need to ensure is that every Claude Code instance passes the same store name.
Using `.mcp.json` (Option A) guarantees this automatically, since all worktrees read from the same file in the repo root.

## Instructing Claude Code to Use engram

Add the contents of [example-claude.md](example-claude.md) to your `CLAUDE.md` or `~/.claude/CLAUDE.md` to instruct Claude Code on how and when to use the memory tools.

## Storage

Stores are SQLite databases located at `~/.config/engram/<name>.db`.
Each entry contains:
- A label (title)
- Content (markdown text)
- A cached embedding vector
- The model name that generated the embedding

## Embedding Model

`engram` uses `sentence-transformers/all-MiniLM-L12-v2` (384-dimensional vectors, 128-token training length).
The model is downloaded from HuggingFace on first run and cached locally.
If the model changes, use `engram reindex <name>` to regenerate all embeddings in a store.
