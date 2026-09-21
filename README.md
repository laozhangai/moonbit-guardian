# MoonBit Guardian

MoonBit Guardian is a community Codex plugin for MoonBit development. It gives an AI coding
workflow version-aware guidance before edits and reproducible evidence after edits.

The plugin provides:

- a Codex Skill for the inspect, guide, implement, check, and verify workflow;
- a local stdio MCP service implemented in MoonBit;
- five tools for project inspection, guidance, real API lookup, compiler checks, and CLI contract verification;
- 15 versioned guidance cards with runnable examples and sources;
- three example MoonBit CLI projects and contract fixtures.

Guardian does not provide a model or upload source code. Code generation remains in the user's
existing AI coding client. The service invokes the user's installed MoonBit toolchain and reports
only checks it actually ran.

## Requirements

- Windows x64 or Linux x64;
- Node.js 22 or newer;
- MoonBit stable toolchain. The release was verified with `moon 0.1.20260915` and `moonc v0.10.13`;
- a native C compiler for native builds (LLVM/Clang on Windows, Clang or GCC on Linux).

The launcher recognizes the official default MoonBit installation directory
`%USERPROFILE%\\.moon\\bin` or `$HOME/.moon/bin`. Put a custom installation directory on `PATH`.

## Install in Codex

Add this repository as a local marketplace source in Codex, then install `moonbit-guardian` from
that marketplace. Start a new Codex thread after installation so the cached Skill and MCP service
are loaded.

The plugin package includes a Windows release binary. Linux release binaries are built by CI and
placed under `dist/linux-x64/` for the corresponding release package.

## Use

Ask Codex for a natural-language workflow, for example:

> Use MoonBit Guardian to inspect this project, look up the real API, fix compiler errors, and verify the CLI contract.

The recommended order is project inspection, targeted guidance/API lookup, code changes, compiler
checks, and contract verification. A contract passing report proves only the declared cases; it is
not a proof of complete program correctness.

## Development

```powershell
cd core
moon update
moon check --deny-warn --target native
moon test --target native
moon check --deny-warn --target wasm-gc
moon test --target wasm-gc
moon fmt --check
cd ..
node scripts/validate-resources.mjs
node scripts/validate-examples.mjs
node tests/mcp-smoke.mjs
```

Use `scripts/build-release.ps1 -Platform windows-x64` on Windows. Linux builds use the analogous
`scripts/build-release.sh` flow in CI. Build and dependency caches are intentionally ignored.

## Repository layout

- `.codex-plugin/`: Codex plugin manifest;
- `skills/`: workflow Skill and contract/reporting references;
- `core/`: reusable MoonBit assertions and native MCP service;
- `guidance/`: versioned guidance cards;
- `examples/`: example projects and delivery contracts;
- `tests/`: MCP protocol and contract fixtures;
- `scripts/`: launcher, release, and resource validation helpers;
- `dist/`: release binaries for supported platforms.

## License

Apache-2.0. Third-party dependency and license information is in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
