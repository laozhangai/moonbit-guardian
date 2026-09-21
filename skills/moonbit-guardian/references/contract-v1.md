# Guardian Delivery Contract v1

The contract is UTF-8 JSON with this top-level shape:

```json
{
  "version": "1",
  "cases": []
}
```

Each case supports:

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Stable case name used in reports. |
| `program` | yes | Executable name or path. `${PROJECT}` and `${TEMP}` are expanded. |
| `args` | no | Argument array; each item supports the same two expansions. |
| `cwd` | no | `temp` (default), `project`, or an expanded explicit path. |
| `stdin` | no | Complete input; Guardian supplies EOF after the value. |
| `fixtures` | no | Relative `{ "path", "content" }` files written below the case temp directory. |
| `timeout_ms` | no | 1-60000; default 10000. |
| `output_limit` | no | Maximum retained characters per stream; 1-8388608, default 1048576. |
| `exit_code` | yes | `{ "kind": "zero" }`, `nonzero`, or `{ "kind": "exact", "value": 2 }`. |
| `stdout`, `stderr` | no | Text expectation object. |
| `stdout_json` | no | JSON Pointer equality assertions. |

A text expectation can combine `exact`, `contains`, `not_contains`, and `empty`. `contains` and `not_contains` are arrays.

```json
{
  "contains": ["created"],
  "not_contains": ["debug"],
  "empty": false
}
```

JSON assertions require stdout to be one valid JSON value:

```json
{
  "stdout_json": [
    { "pointer": "/result/name", "equals": "demo" },
    { "pointer": "/error", "equals": null }
  ]
}
```

Guardian distinguishes a missing pointer from a present `null`. Pointer syntax follows RFC 6901, including `~1` for `/` and `~0` for `~`.

Contracts cannot run arbitrary assertion scripts and cannot auto-accept snapshots. Keep paths relative and fixtures inside the temporary directory.
