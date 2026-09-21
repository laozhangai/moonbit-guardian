import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { resolve } from "node:path";
import { setTimeout as delay } from "node:timers/promises";

const pluginRoot = process.env.GUARDIAN_PLUGIN_ROOT
  ? resolve(process.env.GUARDIAN_PLUGIN_ROOT)
  : resolve(import.meta.dirname, "..");
const repositoryRoot = process.env.GUARDIAN_PROJECT_ROOT
  ? resolve(process.env.GUARDIAN_PROJECT_ROOT)
  : pluginRoot;
const child = spawn(process.execPath, [resolve(pluginRoot, "scripts/launch.mjs")], {
  cwd: pluginRoot,
  env: process.env,
  stdio: ["pipe", "pipe", "pipe"],
  windowsHide: true,
});

let stdoutBuffer = "";
let stderr = "";
const pending = new Map();
const parsedLines = [];

child.stderr.setEncoding("utf8");
child.stderr.on("data", (chunk) => {
  stderr += chunk;
});

child.stdout.setEncoding("utf8");
child.stdout.on("data", (chunk) => {
  stdoutBuffer += chunk;
  for (;;) {
    const newline = stdoutBuffer.indexOf("\n");
    if (newline < 0) break;
    const line = stdoutBuffer.slice(0, newline).trim();
    stdoutBuffer = stdoutBuffer.slice(newline + 1);
    if (!line) continue;
    const message = JSON.parse(line);
    parsedLines.push(message);
    const waiter = pending.get(message.id);
    if (waiter) {
      pending.delete(message.id);
      waiter.resolve(message);
    }
  }
});

let nextId = 1;
function request(method, params) {
  const id = nextId++;
  const promise = new Promise((resolvePromise, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`MCP request timed out: ${method}\nstderr:\n${stderr}`));
    }, 70000);
    pending.set(id, {
      resolve(message) {
        clearTimeout(timer);
        resolvePromise(message);
      },
    });
  });
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
  return promise;
}

function notification(method, params = {}) {
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
}

function structured(response) {
  assert.equal(response.error, undefined, JSON.stringify(response.error));
  return response.result.structuredContent;
}

try {
  const initialized = await request("initialize", {
    protocolVersion: "2025-11-25",
    capabilities: {},
    clientInfo: { name: "guardian-smoke", version: "0.1.0" },
  });
  assert.equal(initialized.result.serverInfo.name, "moonbit-guardian");
  notification("notifications/initialized");

  const listed = await request("tools/list", {});
  assert.deepEqual(
    listed.result.tools.map((tool) => tool.name),
    [
      "inspect_moonbit_project",
      "get_moonbit_guidance",
      "lookup_moonbit_api",
      "check_moonbit_code",
      "verify_delivery_contract",
    ],
  );

  const project = resolve(pluginRoot, "examples", "json-greeter");
  const inspected = structured(
    await request("tools/call", {
      name: "inspect_moonbit_project",
      arguments: { project_path: project },
    }),
  );
  assert.equal(inspected.status, "passed");

  const guidance = structured(
    await request("tools/call", {
      name: "get_moonbit_guidance",
      arguments: { project_path: project, topic: "退出码" },
    }),
  );
  assert.equal(guidance.status, "passed");
  assert.ok(guidance.cards.length >= 1);

  const api = structured(
    await request("tools/call", {
      name: "lookup_moonbit_api",
      arguments: { project_path: project, symbol: "String::length", timeout_ms: 30000 },
    }),
  );
  assert.equal(api.status, "passed");

  const checked = structured(
    await request("tools/call", {
      name: "check_moonbit_code",
      arguments: { project_path: project, mode: "check", timeout_ms: 60000 },
    }),
  );
  assert.equal(checked.status, "passed");

  for (const name of ["json-greeter", "sum-report", "exit-probe"]) {
    const example = resolve(pluginRoot, "examples", name);
    const verified = structured(
      await request("tools/call", {
        name: "verify_delivery_contract",
        arguments: {
          project_path: example,
          contract_path: resolve(example, "guardian.contract.json"),
        },
      }),
    );
    assert.equal(verified.status, "passed", JSON.stringify(verified, null, 2));
    assert.equal(verified.summary.failed, 0);
  }

  const ioVerified = structured(
    await request("tools/call", {
      name: "verify_delivery_contract",
      arguments: {
        project_path: repositoryRoot,
        contract_path: resolve(pluginRoot, "tests", "fixtures", "io.contract.json"),
      },
    }),
  );
  assert.equal(ioVerified.status, "passed", JSON.stringify(ioVerified, null, 2));
  assert.equal(ioVerified.summary.passed, 3);

  const rejected = structured(
    await request("tools/call", {
      name: "verify_delivery_contract",
      arguments: {
        project_path: repositoryRoot,
        contract_path: resolve(
          pluginRoot,
          "tests",
          "fixtures",
          "reject-output-limit.contract.json",
        ),
      },
    }),
  );
  assert.equal(rejected.status, "failed");
  assert.equal(rejected.cases[0].execution.status, "output_limit_exceeded");

  const rejectedInvalid = structured(
    await request("tools/call", {
      name: "verify_delivery_contract",
      arguments: {
        project_path: repositoryRoot,
        contract_path: resolve(
          pluginRoot,
          "tests",
          "fixtures",
          "reject-invalid.contract.json",
        ),
      },
    }),
  );
  assert.equal(rejectedInvalid.status, "failed");
  assert.equal(rejectedInvalid.cases[0].status, "invalid_input");
  assert.match(rejectedInvalid.cases[1].failures.join("\n"), /断言格式无效/);
  assert.match(rejectedInvalid.cases[2].failures.join("\n"), /缺少 equals/);

  const invalid = structured(
    await request("tools/call", {
      name: "check_moonbit_code",
      arguments: { project_path: project, mode: "unknown" },
    }),
  );
  assert.equal(invalid.status, "invalid_input");

  assert.ok(parsedLines.every((message) => message.jsonrpc === "2.0"));
  process.stdout.write(`MCP smoke passed with ${parsedLines.length} JSON-RPC responses.\n`);
} finally {
  child.stdin.end();
  await Promise.race([
    new Promise((resolvePromise) => child.once("exit", resolvePromise)),
    delay(2000).then(() => child.kill("SIGTERM")),
  ]);
}
