/**
 * engram Pi Extension
 *
 * Exposes all engram MCP tools as native pi tools and injects
 * memory instructions into the system prompt.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function engramExtension(pi: ExtensionAPI) {
  // Find engram binary
  const ENGRAM_BIN = (() => {
    const candidates = [
      `${process.env.HOME}/bin/engram`,
      `${process.env.HOME}/dev/engram/engram`,
      "/usr/local/bin/engram",
      "engram",
    ];
    return candidates[0]; // first is most likely, pi.exec resolves via PATH otherwise
  })();

  let stores: string[] = [];

  // Call engram CLI and return stdout
  async function runEngram(args: string[], signal?: AbortSignal): Promise<string> {
    const result = await pi.exec(ENGRAM_BIN, args, { signal });
    if (result.code !== 0) {
      throw new Error(`engram failed: ${result.stderr}`);
    }
    return result.stdout;
  }

  // Parse store names from "list-stores" output (lines like "- storename")
  function parseStores(output: string): string[] {
    const result: string[] = [];
    for (const line of output.split("\n")) {
      const m = line.match(/^\s*-\s+(.+)$/);
      if (m) result.push(m[1].trim());
    }
    return result;
  }

  let startupMessageSent = false;

  // Session start: discover stores
  pi.on("session_start", async (_event, ctx) => {
    startupMessageSent = false;

    try {
      const output = await runEngram(["list-stores"]);
      stores = parseStores(output);
      if (stores.length > 0) {
        ctx.ui.notify(`engram: stores: ${stores.join(", ")}`, "info");
      }
    } catch {
      ctx.ui.notify("engram: not initialized (run `engram create <name>`)", "warning");
    }
  });

  // Inject system prompt with usage instructions
  pi.on("before_agent_start", (event, _ctx) => {
    if (stores.length === 0) return undefined;

    return {
      systemPrompt: event.systemPrompt + `
## Memory (engram)

You have persistent memory via engram. Tools:
- \`engram_recall\` "query" - Search memories
- \`engram_remember\` label, content - Save a memory
- \`engram_list\` - List memories
- \`engram_show\` label - Show a memory
- \`engram_forget\` label - Delete a memory
- \`engram_move\` label, to - Move a memory to another store
- \`engram_find_duplicates\` - Find near-duplicates
- \`engram_list_stores\` - List stores

Active: ${stores.join(", ")}

### Startup
1. \`engram_recall\` "user preferences"
2. \`engram_recall\` "project conventions"
3. If on a branch, recall with branch name

### Write
Save feedback, preferences, conventions, insights immediately.
Always save "★ Insight" callouts silently.

### After Each Response
After responding, check: did you learn new project knowledge, user preferences, or corrections worth persisting? If so, save to engram.
`,
    };
  });

  // Lifecycle hook: SessionStart equivalent
  // On the first user prompt of the session, inject a reminder to recall relevant knowledge
  pi.on("agent_start", (_event, _ctx) => {
    if (stores.length === 0 || startupMessageSent) return;

    startupMessageSent = true;

    pi.sendMessage({
      customType: "engram-hook",
      content: `[engram] Before responding, use engram to recall: (1) user preferences and personality from the global store, (2) project architecture and conventions from the project store${stores.length > 1 ? ", (3) if on a non-main branch, branch-scoped context." : "."} Use list-stores to see available stores, then list and recall as appropriate.`,
      display: true,
    });
  });

  // 1. recall
  pi.registerTool({
    name: "engram_recall",
    label: "engram: Recall",
    description: "Search engram memory for relevant information",
    promptSnippet: "Search memory",
    promptGuidelines: ["Use engram_recall to search for relevant past knowledge"],
    parameters: Type.Object({
      query: Type.String({ description: "Search query" }),
    }),
    async execute(_id, params, signal) {
      const output = await runEngram(["recall", ...stores, "--", params.query], signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // 2. remember
  pi.registerTool({
    name: "engram_remember",
    label: "engram: Remember",
    description: "Save a memory to engram. Before writing, check recall first to avoid duplicates.",
    promptSnippet: "Save to memory",
    parameters: Type.Object({
      label: Type.String({ description: "Memory title" }),
      content: Type.String({ description: "Content to remember" }),
      store: Type.Optional(Type.String({ description: "Store name (default: global)" })),
      overwrite: Type.Optional(Type.Boolean({ description: "Overwrite existing memory" })),
      confidence: Type.Optional(Type.Number({ description: "Confidence 1-10" })),
    }),
    async execute(_id, params, signal) {
      const store = params.store || "global";
      const args = ["remember", store, "--label", params.label, "--content", params.content];
      if (params.overwrite) args.push("--overwrite");
      if (params.confidence) args.push("--confidence", String(params.confidence));
      const output = await runEngram(args, signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // 3. list
  pi.registerTool({
    name: "engram_list",
    label: "engram: List",
    description: "List all memory labels in a store",
    promptSnippet: "List memories",
    parameters: Type.Object({
      store: Type.Optional(Type.String({ description: "Store name (default: first active)" })),
    }),
    async execute(_id, params, signal) {
      const store = params.store || stores[0] || "global";
      const output = await runEngram(["list", store], signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // 4. show
  pi.registerTool({
    name: "engram_show",
    label: "engram: Show",
    description: "Show the full content of a memory by label",
    parameters: Type.Object({
      label: Type.String({ description: "Memory label" }),
      store: Type.Optional(Type.String({ description: "Store name" })),
    }),
    async execute(_id, params, signal) {
      const store = params.store || stores[0] || "global";
      const output = await runEngram(["show", store, params.label], signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // 5. forget
  pi.registerTool({
    name: "engram_forget",
    label: "engram: Forget",
    description: "Delete a memory by label",
    parameters: Type.Object({
      label: Type.String({ description: "Memory label to delete" }),
      store: Type.Optional(Type.String({ description: "Store name" })),
    }),
    async execute(_id, params, signal) {
      const store = params.store || stores[0] || "global";
      const output = await runEngram(["forget", store, params.label], signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // 6. find-duplicates
  pi.registerTool({
    name: "engram_find_duplicates",
    label: "engram: Find Duplicates",
    description: "Find unusually similar memories that may be duplicates",
    parameters: Type.Object({
      store: Type.Optional(Type.String({ description: "Store name" })),
    }),
    async execute(_id, params, signal) {
      const store = params.store || stores[0] || "global";
      const output = await runEngram(["find-duplicates", store], signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // 7. list-stores
  pi.registerTool({
    name: "engram_list_stores",
    label: "engram: List Stores",
    description: "List all available stores",
    promptSnippet: "List stores",
    parameters: Type.Object({}),
    async execute(_id, _params, signal) {
      const output = await runEngram(["list-stores"], signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // 8. move
  pi.registerTool({
    name: "engram_move",
    label: "engram: Move",
    description: "Move a memory from one store to another, preserving its embedding and timestamps",
    parameters: Type.Object({
      label: Type.String({ description: "Label of the memory to move" }),
      to: Type.String({ description: "Destination store" }),
      from: Type.Optional(Type.String({ description: "Source store (default: first active)" })),
    }),
    async execute(_id, params, signal) {
      const from = params.from || stores[0] || "global";
      const output = await runEngram(["move", from, params.to, params.label], signal);
      return { content: [{ type: "text", text: output }], details: {} };
    },
  });

  // Command
  pi.registerCommand("engram", {
    description: "Check engram status",
    handler: async (_args, ctx) => {
      ctx.ui.notify(stores.length > 0
        ? `engram: stores: ${stores.join(", ")}`
        : "engram: not initialized", "info");
    },
  });
}