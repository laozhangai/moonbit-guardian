import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { delimiter, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const pluginRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const platform = process.platform;
const executable =
  platform === "win32"
    ? join(pluginRoot, "dist", "windows-x64", "moonbit-guardian-server.exe")
    : platform === "linux"
      ? join(pluginRoot, "dist", "linux-x64", "moonbit-guardian-server")
      : null;

if (!executable || !existsSync(executable)) {
  const expected = executable ?? `unsupported platform: ${platform}`;
  process.stderr.write(`MoonBit Guardian service binary not found: ${expected}\n`);
  process.exit(1);
}

const home = process.env.USERPROFILE ?? process.env.HOME;
const moonBin = home ? join(home, ".moon", "bin") : null;
const moonExecutable = moonBin
  ? join(moonBin, platform === "win32" ? "moon.exe" : "moon")
  : null;
const pathEntries = (process.env.PATH ?? "").split(delimiter);
const pathValue =
  moonBin && moonExecutable && existsSync(moonExecutable) && !pathEntries.includes(moonBin)
    ? [moonBin, ...pathEntries].filter(Boolean).join(delimiter)
    : process.env.PATH;

const child = spawn(executable, process.argv.slice(2), {
  cwd: pluginRoot,
  env: { ...process.env, PATH: pathValue, MOONBIT_GUARDIAN_HOME: pluginRoot },
  stdio: "inherit",
  windowsHide: true,
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => child.kill(signal));
}

child.on("error", (error) => {
  process.stderr.write(`MoonBit Guardian failed to start: ${error.message}\n`);
  process.exitCode = 1;
});

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
  } else {
    process.exitCode = code ?? 1;
  }
});
