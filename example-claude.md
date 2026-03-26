# Persistence

`engram` is a semantic memory store exposed via MCP.
Use it to persist knowledge across sessions so future instances of yourself can build on what you've already learned.
Tools are prefixed in Claude Code: `mcp__engram__remember`, `mcp__engram__recall`, `mcp__engram__list`, `mcp__engram__forget`, `mcp__engram__find_duplicates`, `mcp__engram__list_stores`.
Bare names used below for readability.

## Stores

- `global`: user preferences, personality, system environment (shared across projects)
- Per-project stores: project-specific knowledge
- Use `list_stores` to see active stores

Memories can be scoped to a git branch for transient context (feature design, WIP, PR status).
Unscoped memories are project-wide and always included in results.
Architecture, conventions, and user preferences are always unscoped.

## Session Startup

1. `recall` "user preferences and personality" (global store)
2. `recall` "project architecture and conventions" (project store)
3. If on a non-main branch, `recall` with the branch name
4. `list` each active store to see available memory labels

Before diving into code, `recall` with a query relevant to the area you're working in.
Prior sessions may have already investigated the area, identified pitfalls, or documented conventions.

## When to Write

**One signal is enough.** Do not wait for confirmation or accumulated evidence.
Save immediately on: feedback, preferences, corrections, emotional signals, project knowledge, conventions, architectural decisions, investigation results.
Any evaluative statement from the user is a learning event worth persisting.

## What to Store

**Global store**: user observations (preferences, learning style, reactions to your behavior, failure modes), agent personality calibration, system environment (available tools, useful commands)
**Project store**: repo organization, infrastructure, languages/frameworks, component relationships and contracts, conventions, operational playbooks
**Project store, branch-scoped**: branch purpose, feature design decisions, PR status, temporary workarounds
**Insights**: non-obvious gotchas, patterns, or architectural lessons discovered during implementation that would cost a future session significant time to rediscover

## Confidence Scoring

Include a confidence score (1-10) on observations about the user or their preferences:
- 1-3: weak/ambiguous signal
- 4-6: moderate, several consistent signals
- 7-8: strong, confirmed across multiple contexts
- 9: explicitly stated
- 10: declared hard constraint

Adjust confidence on update based on accumulated evidence.

## How to Write

- `recall` first to check for duplicates. Update with `overwrite: true` rather than creating a new entry.
- One topic per memory. Several specific memories over one sprawling one.
- Write for a future instance with zero context about the current session.

## What NOT to Store

Session-specific context, incomplete/unverified info, anything already in CLAUDE.md, speculative conclusions.

## Explicit Requests

"Remember X" - save immediately.
"Forget X" - `recall` to find it, then `forget` or overwrite.
