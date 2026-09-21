import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const document = JSON.parse(await readFile(resolve(root, "guidance/cards.json"), "utf8"));
const cards = document.cards;

if (document.schema_version !== "1" || !Array.isArray(cards)) {
  throw new Error("guidance/cards.json 必须使用 schema_version=1 且包含 cards 数组");
}
if (cards.length < 12 || cards.length > 15) {
  throw new Error(`经验卡片数量应为 12-15，实际为 ${cards.length}`);
}

const required = [
  "id",
  "topic",
  "verified_versions",
  "backends",
  "symptom",
  "recommendation",
  "boundary",
  "example",
  "verification",
  "sources",
  "verified_at",
];
const ids = new Set();
for (const card of cards) {
  for (const field of required) {
    if (!(field in card) || card[field] === "" || card[field]?.length === 0) {
      throw new Error(`${card.id ?? "<unknown>"} 缺少字段 ${field}`);
    }
  }
  if (ids.has(card.id)) throw new Error(`重复经验卡片 ID：${card.id}`);
  ids.add(card.id);
  if (!card.sources.every((source) => /^https:\/\//.test(source))) {
    throw new Error(`${card.id} 包含非 HTTPS 来源`);
  }
}

process.stdout.write(`Validated ${cards.length} guidance cards.\n`);
