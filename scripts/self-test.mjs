import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const pluginRoot = resolve(import.meta.dirname, "..");
const output = execFileSync(process.execPath, [resolve(pluginRoot, "scripts/launch.mjs"), "--version"], {
  cwd: pluginRoot,
  encoding: "utf8",
  stdio: ["ignore", "pipe", "inherit"],
});
assert.match(output.trim(), /^moonbit-guardian 0\.1\.0$/);

const selfTest = execFileSync(
  process.execPath,
  [resolve(pluginRoot, "scripts/launch.mjs"), "--self-test"],
  { cwd: pluginRoot, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] },
);
const report = JSON.parse(selfTest);
assert.equal(report.status, "passed");
assert.equal(report.version, "0.1.0");
process.stdout.write("Guardian release self-test passed.\n");
