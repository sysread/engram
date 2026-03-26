# engram

A local semantic memory store for LLMs, exposed via MCP over stdio.

`engram` lets AI agents persist and recall information across sessions using semantic search over embeddings.
It uses `SQLite` for storage and `Bumblebee` for local embedding generation.

## Requirements

- Elixir 1.16+
- No other system dependencies

## Quick Start

```bash
cd /path/to/your/project
engram setup
# Creates store, MCP config, prompt instructions, and hooks
# Claude Code can now use remember, recall, and list tools
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
  setup               Configure engram for the current directory

Options:
  --help    | -h      Show help
  --verbose | -v      Enable verbose output
```

## Installation

Add the repo directory to your `$PATH`, or symlink the `engram` script into a directory already on your `$PATH`:

```bash
ln -s /path/to/engram/repo/engram ~/bin/engram
```

## Quick Setup

The `setup` command configures engram for the current directory in one step:

```bash
cd /path/to/your/project
engram setup
```

This creates or updates three files:
- `.mcp.json` - MCP server configuration (shared across worktrees)
- `CLAUDE.md` - prompt instructions for Claude Code
- `.claude/settings.json` - session hooks for automatic recall/write

Setup prompts you to select from existing stores or create new ones.
A `global` store is always included automatically.

Before making changes, `setup` shows a summary of what it will do and prompts for confirmation.

## Manual Configuration

If you prefer to configure manually, there are several options for the MCP server config.
The key is to ensure that every instance of claude working on the same project uses the same store name (e.g., `my-project`).
Run `engram --help` to see configuration examples with the correct absolute path to the script already filled in.

### MCP Server

Add a `.mcp.json` file to the root of your repository (recommended - shared across worktrees):

```json
{
  "mcpServers": {
    "engram": {
      "type": "stdio",
      "command": "/absolute/path/to/engram",
      "args": ["mcp", "my-project", "global"]
    }
  }
}
```

Or via the CLI:

```bash
claude mcp add engram --scope project -- /absolute/path/to/engram mcp my-project global
```

### Prompt Instructions

Add the contents of [example-claude.md](example-claude.md) to your `CLAUDE.md` or `~/.claude/CLAUDE.md` to instruct Claude Code on how and when to use the memory tools.

### Hooks

Add the hooks from [example-hooks.json](example-hooks.json) to your Claude Code settings (`~/.claude/settings.json` or `.claude/settings.json`).
These automate the recall/write cycle so engram use is habitual rather than opt-in:
- **SessionStart**: recalls context from prior sessions before responding
- **UserPromptSubmit**: evaluates each exchange for persistable knowledge

## Sharing a Store Across Worktrees

The store name (e.g., `my-project`) is what determines which SQLite database engram reads and writes.
Multiple MCP server instances can safely share the same store concurrently - SQLite handles the locking.

The only thing you need to ensure is that every Claude Code instance passes the same store name.
Using `.mcp.json` guarantees this automatically, since all worktrees read from the same file in the repo root.

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
