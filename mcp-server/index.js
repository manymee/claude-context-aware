import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import fs from "fs";

const CONTEXT_FILE = "/tmp/claude-context.json";

const server = new McpServer({
  name: "context-aware",
  version: "1.0.0"
});

server.registerTool(
  "check_context",
  {
    description: "Check current context window usage percentage. Call this periodically during long tasks to monitor context and prepare handoffs before exhaustion.",
    inputSchema: {}
  },
  async () => {
    try {
      const data = JSON.parse(fs.readFileSync(CONTEXT_FILE, "utf-8"));
      const { used_percentage, remaining_percentage, context_size, updated_at } = data;

      if (used_percentage === "unknown" || remaining_percentage === "unknown") {
        return {
          content: [{
            type: "text",
            text: JSON.stringify({
              used_percentage,
              remaining_percentage,
              context_size,
              status: "unknown",
              recommendation: "Context data unavailable. Ensure status line is configured correctly.",
              updated_at
            }, null, 2)
          }]
        };
      }

      const usedPercentage = Number(used_percentage);
      let status = "normal";
      let recommendation = "";

      if (usedPercentage > 65) {
        status = "critical";
        recommendation = "CRITICAL: Auto-compaction imminent (~70%). Write handoff NOW. Inform user immediately.";
      } else if (usedPercentage > 60) {
        status = "overshot";
        recommendation = "OVERSHOT target. Stop work immediately. Write quality handoff—you've already overshot, so handoff quality matters more than stopping sooner.";
      } else if (usedPercentage > 50) {
        status = "handoff";
        recommendation = "HANDOFF ZONE. ~10% context remaining for handoff. Stop new work. Write checkpoint or handoff now.";
      } else if (usedPercentage > 40) {
        status = "wrapping_up";
        recommendation = "Finish current atomic unit of work, then prepare handoff. Do not start large new subtasks.";
      }

      return {
        content: [{
          type: "text",
          text: JSON.stringify({ used_percentage: usedPercentage, remaining_percentage: Number(remaining_percentage), context_size, status, recommendation, updated_at }, null, 2)
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: "text",
          text: `Error reading context: ${error.message}. Ensure status line is configured to write context data.`
        }]
      };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
