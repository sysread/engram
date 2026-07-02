// Injects engram recall reminders at session start, approximating
// Claude Code's SessionStart hook. OpenCode auto-loads any file in
// .opencode/plugins/ — no config needed.

export const EngramReminders = async ({ client }) => {
  return {
    event: async ({ event }) => {
      if (event.type !== "session.created") return

      const id = event.properties?.id
      if (!id) return

      const reminder = `[engram] Before responding, use engram to recall:
(1) user preferences and personality from the global store,
(2) project architecture and conventions from the project store,
(3) if on a non-main branch, branch-scoped context.
Use list-stores to see available stores, then list and recall as appropriate.`

      try {
        await client.session.prompt({
          path: { id },
          body: { noReply: true, parts: [{ type: "text", text: reminder }] },
        })
      } catch (_e) {
        // fail silently — better than breaking the session
      }
    },
  }
}
