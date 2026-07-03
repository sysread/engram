# engram

[![test](https://github.com/sysread/engram/actions/workflows/test.yml/badge.svg)](https://github.com/sysread/engram/actions/workflows/test.yml)

## Synopsis

`engram` is a simple `stdio`-based MCP server that allows LLMs to store and retrieve memories locally.

## Description

Provides an offline, local memory store for LLMs, accessible via a simple command-line interface and a `stdio` MCP server.
Created stores may be shared between multiple applications, agents, and worktrees, allowing for consistent memory access between different LLM-powered tools, projects, and sessions.

For example, `claude`'s built-in memory system is file-based and tied to the directory it's running in, so memories aren't shared across worktrees in the same repo.
This solves that by sharing the same named store across worktrees.

## Usage

```
engram <command> [options]

Commands:
  list-stores                          List existing stores
  list             <name>              List memory labels in a store
  create           <name>              Create a new store
  remove           <name>              Remove a store
  reindex          <name>              Regenerate all embeddings
  find-duplicates  [-H] <name>         Find memories with similar content
  remember         <name> --label...   Save a memory (--label, --content, --overwrite, --branch, --confidence)
  forget           <name> <label>      Remove a memory by label
  move             <src> <dst> <slug>...  Move memories to another store (keeps embedding)
  show             <name> <slug>       Display a single memory by slug
  dump             <name> ...          Output all memories for one or more stores
  recall           <name> ... -- <q>   Semantic search across one or more stores
  mcp              [<name> ... | --all]  Start the MCP server (auto-discovers stores)
  mcp              --config [--opencode]  Emit MCP config JSON
  init             <name>              Register a store for this project directory

Options:
  --help    | -h      Show help
  --verbose | -v      Enable verbose output
```

## Installation

Install dependencies:

```bash
# macOS
xcode-select --install  # C++ compiler, skip if already installed
brew install elixir

# Ubuntu/Debian
sudo apt-get install build-essential elixir
```

Add the repo directory to your `$PATH`, or symlink the `engram` script into a directory already on your `$PATH`:

```bash
ln -s /path/to/engram/repo/engram ~/bin/engram
```

## Quick Start

```bash
cd /path/to/your/project
engram init my-project
```

`init` creates a store named `my-project` and registers it in `~/.config/engram/projects.json` keyed by the repo's canonical path. The `global` store is included automatically for all projects.

### MCP Server Config

Add the MCP server to your AI tool's config. `engram mcp --config` emits the correct JSON for each tool:

```bash
# Claude Code (add to .mcp.json)
engram mcp --config --claude

# OpenCode (add to opencode.json)
engram mcp --config --opencode
```

Or manually:

**Claude Code** (`.mcp.json`):
```json
{
  "mcpServers": {
    "engram": {
      "type": "stdio",
      "command": "/absolute/path/to/engram",
      "args": ["mcp"]
    }
  }
}
```

**OpenCode** (`opencode.json`):
```json
{
  "mcp": {
    "engram": {
      "type": "local",
      "command": ["/absolute/path/to/engram", "mcp"],
      "enabled": true
    }
  }
}
```

No store args are needed -- `engram mcp` auto-discovers stores from `projects.json` using `git rev-parse --git-common-dir`, which works across worktrees.

These configs can go in the project root or in your global tool config (e.g. `~/.claude/settings.json` for Claude Code).

### Prompt Instructions

Add the engram instruction file to your AI tool's instructions:

**Claude Code**: append [example-claude.md](example-claude.md) to `.claude/CLAUDE.md` or `~/.claude/CLAUDE.md`.

**OpenCode**: add `.opencode/instructions/engram.md` to your `opencode.json` instructions array.

### Hooks (Claude Code)

Add the hooks from [example-hooks.json](example-hooks.json) to `.claude/settings.local.json`. These automate recall on session start and prompt evaluation for new knowledge.

## Sharing a Store Across Worktrees

Store discovery uses `git rev-parse --git-common-dir`, which resolves to the main repo's `.git` directory even from inside a worktree. All worktrees map to the same key in `projects.json`, so store lists are automatically consistent.

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
