#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { Agent } from "@cursor/sdk";

function emit(event) {
  process.stdout.write(`${JSON.stringify(event)}\n`);
}

function extractText(result) {
  if (typeof result?.result === "string" && result.result.trim()) {
    return result.result.trim();
  }

  const messages = result?.messages ?? result?.conversation ?? [];
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const item = messages[index];
    const role = item?.role ?? item?.type ?? item?.message?.role;
    if (role !== "assistant") continue;

    const content = item?.content ?? item?.message?.content;
    if (typeof content === "string" && content.trim()) {
      return content.trim();
    }

    if (Array.isArray(content)) {
      const text = content
        .filter((block) => block?.type === "text" && typeof block?.text === "string")
        .map((block) => block.text)
        .join("\n")
        .trim();
      if (text) return text;
    }
  }

  return "";
}

function toolNameFromUpdate(update) {
  const tc = update.toolCall;
  if (tc?.type) return tc.type;
  if (update.toolName) return update.toolName;
  return update.name ?? "tool";
}

function toolDetailFromUpdate(update) {
  const tc = update.toolCall;
  if (!tc?.args) return undefined;

  const args = tc.args;
  switch (tc.type) {
    case "read":
      return args.path ?? args.targetFile ?? args.file;
    case "write":
      return args.path ?? args.filePath;
    case "edit":
      return args.path ?? args.filePath;
    case "delete":
      return args.path;
    case "grep":
      return args.pattern ?? args.query;
    case "glob":
      return args.globPattern ?? args.pattern;
    case "shell":
      return args.command;
    case "semSearch":
      return args.query;
    case "task":
      return args.description ?? args.prompt;
    case "ls":
      return args.path ?? args.targetDirectory;
    case "readLints":
      return args.path;
    case "updateTodos":
      return Array.isArray(args.todos)
        ? `${args.todos.length} 项待办`
        : undefined;
    case "webSearch":
      return args.searchTerm ?? args.query;
    case "mcpCallTool":
      return args.toolName
        ? `${args.server ?? "mcp"}/${args.toolName}`
        : args.server;
    case "mcpGetTools":
      return args.pattern ?? args.server;
    case "mcpFetchResource":
      return args.uri;
    case "generateImage":
      return args.description?.slice(0, 80);
    case "switchMode":
      return args.targetModeId ?? args.target_mode_id;
    default:
      break;
  }

  const firstString = Object.values(args).find((v) => typeof v === "string" && v.trim());
  return typeof firstString === "string" ? firstString : undefined;
}

function toolResultFromUpdate(update) {
  const tc = update.toolCall;
  const result = update.result ?? tc?.result ?? update.output;
  if (typeof result === "string" && result.trim()) {
    return result.trim().length > 400 ? `${result.trim().slice(0, 397)}…` : result.trim();
  }
  if (result && typeof result === "object") {
    const text = JSON.stringify(result);
    return text.length > 400 ? `${text.slice(0, 397)}…` : text;
  }
  return undefined;
}

function sanitizeModelId(raw) {
  const trimmed = String(raw ?? "").trim();
  if (!trimmed) return "composer-2.5";
  if (trimmed.startsWith("crsr_")) return "composer-2.5";
  return trimmed;
}

function toolErrorFromUpdate(update) {
  const err = update.error ?? update.toolCall?.error;
  if (typeof err === "string" && err.trim()) return err.trim();
  if (err && typeof err === "object" && typeof err.message === "string") return err.message;

  const result = update.result ?? update.toolCall?.result ?? update.output;
  if (result && typeof result === "object") {
    const exitCode = result.exitCode ?? result.exit_code;
    const stderr = result.stderr ?? result.stderrText ?? result.error;
    if (exitCode != null && exitCode !== 0) {
      const stderrText = typeof stderr === "string" ? stderr.trim() : "";
      return stderrText || `命令退出码 ${exitCode}`;
    }
    if (typeof stderr === "string" && stderr.trim()) {
      return stderr.trim();
    }
  }
  return undefined;
}

function emitToolEvent(update, status) {
  const name = toolNameFromUpdate(update);
  const detail = toolDetailFromUpdate(update);
  const callId = update.callId ?? update.toolCall?.callId;
  const payload = { event: "tool", name, status, callId, detail };
  if (status === "completed" || status === "failed") {
    const result = toolResultFromUpdate(update);
    const error = toolErrorFromUpdate(update);
    if (result) payload.result = result;
    if (error) payload.error = error;
  }
  emit(payload);
}

async function main() {
  const raw = readFileSync(0, "utf8");
  const input = JSON.parse(raw);

  const apiKey = (input.apiKey || process.env.CURSOR_API_KEY || "").trim();
  if (!apiKey) {
    emit({ event: "needs_auth", error: "未配置 Cursor API Key" });
    return;
  }

  const history = Array.isArray(input.history) ? input.history : [];
  const message = String(input.message ?? "").trim();
  if (!message) {
    throw new Error("消息不能为空。");
  }

  const systemInstruction = String(input.systemInstruction ?? "").trim();

  let prompt = message;
  if (history.length > 0) {
    const transcript = history
      .map((entry) => {
        const role = entry.role === "assistant" ? "assistant" : "user";
        return `${role}: ${entry.content}`;
      })
      .join("\n\n");
    prompt = `${transcript}\n\nuser: ${message}`;
  }

  if (systemInstruction) {
    prompt = `${systemInstruction}\n\n---\n\n${prompt}`;
  }

  const autoAuthorize = Boolean(input.autoAuthorize);
  const modelId = sanitizeModelId(input.model || "composer-2.5");
  const agentOptions = {
    apiKey,
    model: { id: modelId },
    local: {
      cwd: input.cwd || process.cwd(),
      settingSources: autoAuthorize ? ["all"] : [],
    },
  };

  let thinkingText = "";
  let responseText = "";

  const agent = await Agent.create(agentOptions);
  try {
    const run = await agent.send(prompt, {
      model: { id: modelId },
      onDelta: ({ update }) => {
        if (
          (update.type === "thinking-delta" || update.type === "reasoning-delta") &&
          update.text
        ) {
          thinkingText += update.text;
          emit({ event: "thinking", delta: update.text });
        } else if (update.type === "text-delta" && update.text) {
          responseText += update.text;
          emit({ event: "text", delta: update.text });
        } else if (update.type === "tool-call-started") {
          emitToolEvent(update, "running");
        } else if (update.type === "tool-call-completed") {
          emitToolEvent(update, "completed");
        } else if (update.type === "tool-call-failed" || update.type === "tool-call-error") {
          emitToolEvent(update, "failed");
        } else if (update.type === "partial-tool-call") {
          emitToolEvent(update, "running");
        }
      },
    });

    for await (const event of run.stream()) {
      const chunk =
        event.type === "thinking"
          ? event.text
          : event.type === "reasoning"
            ? event.text ?? event.content
            : null;
      if (chunk && !thinkingText.includes(chunk)) {
        thinkingText += chunk;
        emit({ event: "thinking", delta: chunk });
      }
    }

    const result = await run.wait();
    if (result.status === "error") {
      throw new Error(`Cursor 本地对话失败（run: ${result.id ?? "unknown"}）`);
    }

    const finalText = responseText.trim() || extractText(result);
    if (!finalText && !thinkingText.trim()) {
      throw new Error("Cursor 返回了空内容。");
    }

    emit({
      event: "done",
      text: finalText,
      thinking: thinkingText.trim() || undefined,
    });
  } finally {
    agent.close();
  }
}

main().catch((error) => {
  emit({
    event: "error",
    error: error instanceof Error ? error.message : String(error),
  });
  process.exit(1);
});
