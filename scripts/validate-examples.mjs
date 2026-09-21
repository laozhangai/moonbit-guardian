import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const pluginRoot = resolve(import.meta.dirname, "..");
const examples = ["json-greeter", "sum-report", "exit-probe"];

for (const example of examples) {
  const cwd = resolve(pluginRoot, "examples", example);
  for (const args of [
    ["fmt", "--check"],
    ["check", "--deny-warn", "--target", "wasm-gc"],
  ]) {
    execFileSync("moon", args, { cwd, stdio: "inherit" });
  }
}

process.stdout.write(`Validated ${examples.length} example projects.\n`);
