# memory branch

## Purpose
New memory system for fnord: session memory indexing, long-term memory consolidation, and parallel memory reflection during finalize.

## Key Features Implemented
- Session memory with index_status lifecycle: nil -> :new -> :analyzed | :rejected | :incorporated | :merged | :ignore
- Memory.Indexer (Services.MemoryIndexer) for background session->long-term promotion
- Memory.Consolidator + Services.MemoryConsolidation for `--long-con` consolidation
- AI.Agent.Coordinator.Memory.reflect/1 -- parallel memory reflection step alongside finalize
- AI.Agent.Coordinator.Memory.recall_prompt/0 -- lightweight recall prompt for @common (full memory guidance moved to reflect step)
- Memory.Session.list/0 filters out promoted statuses (:incorporated, :merged) via @promoted_statuses
- :ignore status for forked conversations (Store.Project.Conversation.fork/1 stamps existing session memories)
- Memory.search/3 timing metrics (Memory.search_stats/0) displayed in ask output
- SafeJson.Serialize impl for Memory includes index_status

## Architecture Notes
- reflect/1 runs via Services.Globals.Spawn.async in parallel with finalize completion
- reflect/1 calls AI.Completion.get directly (bypasses Glue -- no conversation writeback)
- reflect/1 toolbox contains only memory_tool; side effects (tool calls) are the point, response text discarded
- Session memory dedup across --follow: pragmatic approach -- reflect agent sees existing memories as context, indexer/consolidator handles remaining duplication
- Conversation compaction (tersification/summarization) can destroy message indices, making index-based turn tracking fragile

## Rebase Status
Successfully rebased onto origin/main (c122a9bf) as of 2026-03-02.
Main brought: SafeJson wrapper (replaces Jason), UI.feedback_user in coordinator, task title in add_task tool.
