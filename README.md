# engram

A local semantic memory store for LLMs, exposed via MCP over stdio.

`engram` lets AI agents persist and recall information across sessions using semantic search over embeddings.
It uses `SQLite` for storage and `Bumblebee` for local embedding generation.

## Requirements

- Elixir 1.16+
- No other system dependencies

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

Install `elixir`:

```bash
brew install elixir
```

Add the repo directory to your `$PATH`, or symlink the `engram` script into a directory already on your `$PATH`:

```bash
ln -s /path/to/engram/repo/engram ~/bin/engram
```

## Quick Start

```bash
cd /path/to/your/project
engram setup
```

`setup` writes to four locations:
- `.mcp.json` - MCP server config
- `.claude/CLAUDE.md` - prompt instructions for Claude Code
- `.claude/settings.local.json` - session hooks for automatic recall/write
- `.gitignore` - adds `.mcp.json` and `.claude/` to keep config out of version control

Setup prompts you to select from existing stores or create new ones.
A `global` store is always included automatically.

Before making changes, `setup` shows a summary of what it will do and prompts for confirmation.

## Manual Configuration

If you prefer to configure manually, these are the steps `setup` automates.

### MCP Server

Add a `.mcp.json` file to the root of your project:

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

### Prompt Instructions

Add the contents of [example-claude.md](example-claude.md) to `.claude/CLAUDE.md` or `~/.claude/CLAUDE.md` to instruct Claude Code on how and when to use the memory tools.

```bash
cat example-claude.md >> .claude/CLAUDE.md
```

### Hooks

Add the hooks from [example-hooks.json](example-hooks.json) to `.claude/settings.local.json`.
These automate the recall/write cycle so engram use is habitual rather than opt-in:
- **SessionStart**: recalls context from prior sessions before responding
- **UserPromptSubmit**: evaluates each exchange for persistable knowledge

## Sharing a Store Across Worktrees

The store name (e.g., `my-project`) is what determines which SQLite database engram reads and writes.
Multiple MCP server instances can safely share the same store concurrently - SQLite handles the locking.

All worktrees share the same `.mcp.json` from the repo root, so the config is automatically consistent.

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
