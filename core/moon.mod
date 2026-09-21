// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "moonbit-guardian/guardian"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/laozhangai/moonbit-guardian"

license = "Apache-2.0"

keywords = [ "moonbit", "mcp", "verification", "codex" ]

preferred_target = "native"

description = "Core engine for version-aware MoonBit guidance and delivery verification"

import {
  "moonbitlang/async@0.22.1",
  "123123213weqw/moonbit_mcp@0.1.0",
}
