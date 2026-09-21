---
name: moonbit-guardian
description: Guide, diagnose, and verify local MoonBit library or CLI development with versioned experience, real `moon ide doc` API evidence, compiler/test results, and JSON delivery contracts. Use for creating MoonBit projects, fixing MoonBit diagnostics, checking AI-generated MoonBit code, or validating CLI behavior; do not use it as a general tutorial when no project or deliverable is in scope.
---

# MoonBit Guardian

Use Guardian as an evidence loop around ordinary coding. Guardian does not generate code by itself and does not replace the user's installed MoonBit toolchain.

## Workflow

1. Call `inspect_moonbit_project` before material edits. Treat its paths, manifests, toolchain versions, and missing conditions as facts.
2. Call `get_moonbit_guidance` only for the current topic or diagnostic. If it returns `unsupported`, preserve the compiler evidence and continue with targeted API lookup rather than inventing a rule.
3. Before using an unfamiliar MoonBit symbol, call `lookup_moonbit_api`. Cite the returned `moon ide doc` query basis when the API choice matters.
4. Make the smallest implementation change consistent with the project style.
5. Call `check_moonbit_code` in `check` mode after edits and in `test` mode when tests exist. A parsed suggestion never overrides a nonzero exit status or raw diagnostic.
6. For a CLI delivery, write or review a version 1 contract before fixing behavior, then call `verify_delivery_contract`. Read [references/contract-v1.md](references/contract-v1.md) when creating or changing a contract.
7. Repeat the edit/check/verify loop until the requested scope passes or a concrete blocker remains.

## Evidence Rules

- Report only actions the tools actually ran. Mark skipped checks as `未验证`.
- Distinguish `invalid_input`, `execution_failed`, `timed_out`, `output_limit_exceeded`, and an assertion `failed`; they imply different next actions.
- Do not call a check successful when output was truncated or a diagnostic format was not understood.
- Keep the contract fixed during implementation. Change it only when the user requirement changes, and explain that change separately.
- Treat a passing contract as proof only for its declared cases, not proof that the whole program is correct.
- Do not claim the temporary working directory is a security sandbox. Contract cases execute local project code with the user's permissions.
- Do not upload source code or call a remote model as part of Guardian verification.

## Mode Guidance

For a new project, inspect the parent/project path, query uncertain APIs, build a minimal vertical slice, then check, test, and verify its public CLI behavior.

For a failing project, start from `check_moonbit_code`. Keep the original diagnostic visible, fetch only matching guidance, query any proposed replacement API, then rerun the same check.

For README acceptance, extract only explicit observable requirements into a contract. Include at least one success case and, when specified by the README, failure and stdin cases. Read [references/reporting.md](references/reporting.md) before the final handoff.
