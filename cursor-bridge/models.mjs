#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { Cursor } from "@cursor/sdk";

function emit(event) {
  process.stdout.write(`${JSON.stringify(event)}\n`);
}

async function main() {
  const raw = readFileSync(0, "utf8");
  const input = JSON.parse(raw || "{}");

  const apiKey = (input.apiKey || process.env.CURSOR_API_KEY || "").trim();
  if (!apiKey) {
    emit({ event: "needs_auth", error: "未配置 Cursor API Key" });
    return;
  }

  const models = await Cursor.models.list({ apiKey });
  const simplified = models.map((model) => ({
    id: model.id,
    label: model.name ?? model.id,
    description: model.description ?? undefined,
  }));

  emit({ event: "done", models: simplified });
}

main().catch((error) => {
  emit({
    event: "error",
    error: error instanceof Error ? error.message : String(error),
  });
  process.exit(1);
});
