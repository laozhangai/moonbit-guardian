# Verification Reporting

Summarize the observable result first, then list evidence and gaps.

Use these states consistently:

| State | Meaning |
| --- | --- |
| `通过` | The named command or declared case ran and satisfied its checks. |
| `未通过` | It ran and returned a nonzero status or failed an assertion. |
| `未验证` | It was not run or no requirement covered it. |
| `环境缺失` | A required tool, manifest, binary, or dependency was absent. |
| `执行失败` | Guardian could not start or complete the operation. |

Include the actual MoonBit toolchain version, the commands/evidence named by Guardian, contract case totals, and any output truncation. Do not rewrite raw compiler facts as model certainty. End with the smallest concrete next action when something remains unresolved.
