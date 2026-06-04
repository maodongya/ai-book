#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { MsEdgeTTS, OUTPUT_FORMAT } from "msedge-tts";

async function main() {
  const raw = readFileSync(0, "utf8");
  const input = JSON.parse(raw);
  const text = String(input.text ?? "").trim();
  const voice = String(input.voice ?? "zh-CN-XiaoxiaoNeural").trim();
  const outputFormat = String(input.outputFormat ?? "").trim();
  const rate = String(input.rate ?? "+0%").trim();
  const pitch = String(input.pitch ?? "+0Hz").trim();
  const volume = String(input.volume ?? "+0%").trim();
  const outputPath = String(input.outputPath ?? "").trim();

  if (!text) {
    emit({ event: "error", error: "文本不能为空" });
    return;
  }

  try {
    const tts = new MsEdgeTTS();
    const format =
      OUTPUT_FORMAT[outputFormat] ??
      OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3;
    await tts.setMetadata(voice, format);
    const { audioStream } = tts.toStream(text, { rate, pitch, volume });

    const chunks = [];
    for await (const chunk of audioStream) {
      chunks.push(chunk);
    }

    const audio = Buffer.concat(chunks);
    if (!audio.length) {
      emit({ event: "error", error: "语音合成返回空音频" });
      return;
    }

    if (outputPath) {
      writeFileSync(outputPath, audio);
      emit({ event: "done", outputPath, bytes: audio.length });
    } else {
      emit({ event: "done", audioBase64: audio.toString("base64"), bytes: audio.length });
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    emit({ event: "error", error: message });
  }
}

function emit(event) {
  process.stdout.write(`${JSON.stringify(event)}\n`);
}

main();
