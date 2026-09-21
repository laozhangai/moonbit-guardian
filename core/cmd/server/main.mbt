///|
let default_timeout_ms : Int = 10000

///|
let max_timeout_ms : Int = 60000

///|
let default_output_limit : Int = 1048576

///|
fn json_get(value : Json, key : String) -> Json? {
  match value {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn json_string(value : Json, key : String) -> String? {
  match json_get(value, key) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_int(value : Json, key : String) -> Int? {
  match json_get(value, key) {
    Some(Number(number, ..)) => Some(number.to_int())
    _ => None
  }
}

///|
fn json_strings(value : Json, key : String) -> Array[String]? {
  match json_get(value, key) {
    Some(Array(values)) => {
      let result : Array[String] = []
      for item in values {
        match item {
          String(text) => result.push(text)
          _ => return None
        }
      }
      Some(result)
    }
    _ => None
  }
}

///|
fn clamp_timeout(value : Int?) -> Int {
  match value {
    Some(ms) if ms < 1 => 1
    Some(ms) if ms > max_timeout_ms => max_timeout_ms
    Some(ms) => ms
    None => default_timeout_ms
  }
}

///|
fn clip_output(text : String, limit : Int) -> (String, Bool) {
  if text.length() <= limit {
    (text, false)
  } else {
    (text[:limit].to_owned(), true)
  }
}

///|
async fn run_command(
  program : String,
  args : Array[String],
  cwd : String,
  stdin_text? : String,
  timeout_ms? : Int,
  output_limit? : Int = default_output_limit,
) -> Json {
  let timeout = clamp_timeout(timeout_ms)
  let started_at = @env.now()
  let attempt = @async.with_timeout_opt(timeout, () => {
    match stdin_text {
      Some(input) => {
        let temp = @fs.tmpdir(prefix="moonbit-guardian-stdin-")
        defer @fs.rmdir(temp, recursive=true)
        let input_path = "\{temp}/stdin.txt"
        @fs.write_file(input_path, input)
        let source = @process.redirect_from_file(input_path)
        @process.collect_output(
          program,
          args,
          stdin=source,
          cwd~,
          no_console_window=true,
        )
      }
      None =>
        @process.collect_output(program, args, cwd~, no_console_window=true)
    }
  }) catch {
    error => {
      let detail = @debug.to_string(error)
      return {
        "status": "execution_failed",
        "toolchain_version": null,
        "program": program,
        "args": args,
        "exit_code": null,
        "stdout": "",
        "stderr": detail,
        "timed_out": false,
        "output_truncated": false,
        "duration_ms": (@env.now() - started_at).to_int(),
        "evidence": [detail],
      }
    }
  }
  match attempt {
    None =>
      {
        "status": "timed_out",
        "toolchain_version": null,
        "program": program,
        "args": args,
        "exit_code": null,
        "stdout": "",
        "stderr": "",
        "timed_out": true,
        "output_truncated": false,
        "duration_ms": (@env.now() - started_at).to_int(),
        "evidence": ["进程超过 \{timeout}ms，已请求取消并回收"],
      }
    Some((exit_code, stdout_data, stderr_data)) => {
      let stdout = stdout_data.text() catch {
        _ => "<stdout 不是有效 UTF-8>"
      }
      let stderr = stderr_data.text() catch {
        _ => "<stderr 不是有效 UTF-8>"
      }
      let (stdout_clipped, stdout_limited) = clip_output(stdout, output_limit)
      let (stderr_clipped, stderr_limited) = clip_output(stderr, output_limit)
      let truncated = stdout_limited || stderr_limited
      {
        "status": if truncated {
          "output_limit_exceeded"
        } else if exit_code == 0 {
          "passed"
        } else {
          "failed"
        },
        "toolchain_version": null,
        "program": program,
        "args": args,
        "exit_code": exit_code,
        "stdout": stdout_clipped,
        "stderr": stderr_clipped,
        "timed_out": false,
        "output_truncated": truncated,
        "duration_ms": (@env.now() - started_at).to_int(),
        "evidence": [
          "以程序路径和参数数组执行，未经过 shell", "stdout 与 stderr 已并发读取",
        ],
      }
    }
  }
}

///|
async fn moon_version(project_path : String) -> Json {
  run_command(
    "moon",
    ["version", "--all"],
    project_path,
    timeout_ms=5000,
    output_limit=65536,
  )
}

///|
async fn inspect_project(args : Json) -> Json {
  let requested = json_string(args, "project_path").unwrap_or(".")
  if !@fs.exists(requested) {
    return {
      "status": "invalid_input",
      "project_path": requested,
      "toolchain_version": null,
      "evidence": ["项目路径不存在"],
      "missing_conditions": ["project_path"],
      "output_truncated": false,
    }
  }
  let root = @fs.realpath(requested)
  let has_mod = @fs.exists("\{root}/moon.mod")
  let has_legacy_mod = @fs.exists("\{root}/moon.mod.json")
  let has_pkg = @fs.exists("\{root}/moon.pkg")
  let version = moon_version(root)
  let tree = if has_mod {
    Some(
      run_command("moon", ["tree"], root, timeout_ms=10000, output_limit=262144),
    )
  } else {
    None
  }
  let missing : Array[Json] = []
  if !has_mod && !has_legacy_mod {
    missing.push("moon.mod")
  }
  let toolchain_status = json_string(version, "status").unwrap_or(
    "execution_failed",
  )
  if toolchain_status != "passed" {
    missing.push("moon toolchain")
  }
  {
    "status": if !has_mod && !has_legacy_mod {
      "unsupported"
    } else if toolchain_status != "passed" {
      "execution_failed"
    } else {
      "passed"
    },
    "project_path": root,
    "module_manifest": if has_mod {
      "moon.mod"
    } else if has_legacy_mod {
      "moon.mod.json"
    } else {
      null
    },
    "package_manifest_at_root": has_pkg,
    "target_backend": "项目配置决定；Guardian 原生服务运行于 native 后端",
    "toolchain": version,
    "dependencies": tree,
    "missing_conditions": missing,
    "evidence": ["文件存在性检查", "moon version --all", "moon tree"],
    "output_truncated": false,
  }
}

///|
fn guardian_home() -> String? {
  @env.get_env_var("MOONBIT_GUARDIAN_HOME")
}

///|
async fn get_guidance(args : Json) -> Json {
  let topic = json_string(args, "topic").unwrap_or("")
  let diagnostic = json_string(args, "diagnostic_code").unwrap_or("")
  let query = if !diagnostic.is_empty() { diagnostic } else { topic }
  let home = match guardian_home() {
    Some(path) => path
    None =>
      return {
        "status": "unsupported",
        "toolchain_version": null,
        "cards": [],
        "evidence": ["启动器未设置 MOONBIT_GUARDIAN_HOME"],
        "output_truncated": false,
      }
  }
  let path = "\{home}/guidance/cards.json"
  if !@fs.exists(path) {
    return {
      "status": "unsupported",
      "toolchain_version": null,
      "cards": [],
      "evidence": ["经验库文件不存在：\{path}"],
      "output_truncated": false,
    }
  }
  let document = @fs.read_file(path).json()
  let cards = match json_get(document, "cards") {
    Some(Array(values)) => values
    _ => []
  }
  let needle = query.to_lower()
  let matched : Array[Json] = []
  for card in cards {
    if needle.is_empty() || card.stringify().to_lower().contains(needle) {
      matched.push(card)
    }
  }
  {
    "status": if matched.is_empty() {
      "unsupported"
    } else {
      "passed"
    },
    "toolchain_version": "moonc v0.10.13 / moon 0.1.20260915",
    "query": query,
    "cards": matched,
    "evidence": [
      path, "经验卡片只来自随插件发布且经过测试的版本库",
    ],
    "output_truncated": false,
  }
}

///|
async fn lookup_api(args : Json) -> Json {
  let project_path = json_string(args, "project_path").unwrap_or(".")
  let symbol = match json_string(args, "symbol") {
    Some(value) if !value.is_empty() => value
    _ =>
      return {
        "status": "invalid_input",
        "toolchain_version": null,
        "evidence": ["symbol 必须是非空字符串"],
        "output_truncated": false,
      }
  }
  let result = run_command(
    "moon",
    ["ide", "doc", "--no-check", symbol],
    project_path,
    timeout_ms=clamp_timeout(json_int(args, "timeout_ms")),
    output_limit=262144,
  )
  {
    "status": json_string(result, "status").unwrap_or("execution_failed"),
    "toolchain_version": "由 inspect_moonbit_project 返回",
    "symbol": symbol,
    "query_basis": "moon ide doc --no-check \{symbol}",
    "result": result,
    "evidence": ["实际调用项目工具链的 moon ide doc"],
    "output_truncated": json_get(result, "output_truncated").unwrap_or(false),
  }
}

///|
async fn check_code(args : Json) -> Json {
  let project_path = json_string(args, "project_path").unwrap_or(".")
  let mode = json_string(args, "mode").unwrap_or("check")
  let command_args = match mode {
    "check" => ["check", "--deny-warn", "--output-json"]
    "test" => ["test", "--deny-warn"]
    _ =>
      return {
        "status": "invalid_input",
        "toolchain_version": null,
        "mode": mode,
        "evidence": ["mode 仅支持 check 或 test"],
        "output_truncated": false,
      }
  }
  let result = run_command(
    "moon",
    command_args,
    project_path,
    timeout_ms=clamp_timeout(json_int(args, "timeout_ms")),
    output_limit=1048576,
  )
  {
    "status": json_string(result, "status").unwrap_or("execution_failed"),
    "toolchain_version": "由同一 moon 可执行文件执行",
    "mode": mode,
    "result": result,
    "diagnostics_parsed": mode == "check",
    "diagnostics_note": "保留编译器原始 JSON/文本；未知格式不会被判定为成功",
    "evidence": ["moon \{command_args.join(" ")}"],
    "output_truncated": json_get(result, "output_truncated").unwrap_or(false),
  }
}

///|
fn safe_relative_path(path : String) -> Bool {
  !path.is_empty() &&
  !path.has_prefix("/") &&
  !path.has_prefix("\\") &&
  !path.contains(":") &&
  !path.split("/").any(part => part == "..")
}

///|
async fn write_fixture(root : String, fixture : Json) -> String? {
  let relative = match json_string(fixture, "path") {
    Some(value) => value
    None => return Some("fixture.path 必须是安全的相对路径")
  }
  let normalized = relative.replace_all(old="\\", new="/")
  if !safe_relative_path(normalized) {
    return Some("fixture.path 必须是安全的相对路径")
  }
  let content = json_string(fixture, "content").unwrap_or("")
  let parts = normalized.split("/").map(part => part.to_owned()).collect()
  let mut directory = root
  for index = 0; index + 1 < parts.length(); index = index + 1 {
    directory = "\{directory}/\{parts[index]}"
    if !@fs.exists(directory) {
      @fs.mkdir(directory)
    }
  }
  @fs.write_file("\{root}/\{normalized}", content)
  None
}

///|
fn text_expectation(value : Json?) -> @guardian.TextExpectation? {
  match value {
    Some(Object(fields)) => {
      let exact = match fields.get("exact") {
        None => None
        Some(String(text)) => Some(text)
        _ => return None
      }
      let contains = match fields.get("contains") {
        None => []
        Some(Array(values)) => {
          let result : Array[String] = []
          for value in values {
            match value {
              String(text) => result.push(text)
              _ => return None
            }
          }
          result
        }
        _ => return None
      }
      let not_contains = match fields.get("not_contains") {
        None => []
        Some(Array(values)) => {
          let result : Array[String] = []
          for value in values {
            match value {
              String(text) => result.push(text)
              _ => return None
            }
          }
          result
        }
        _ => return None
      }
      let empty = match fields.get("empty") {
        None => None
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => return None
      }
      Some({ exact, contains, not_contains, empty, })
    }
    Some(_) => None
    None => None
  }
}

///|
fn assert_json_output(stdout : String, assertions : Json?) -> Array[String] {
  let failures : Array[String] = []
  let values = match assertions {
    Some(Array(items)) if !items.is_empty() => items
    _ => return failures
  }
  let parsed = @json.parse(stdout) catch {
    _ => {
      failures.push("stdout 不是合法 JSON")
      return failures
    }
  }
  for assertion in values {
    let pointer = json_string(assertion, "pointer").unwrap_or("")
    let expected = match json_get(assertion, "equals") {
      Some(value) => value
      None => {
        failures.push("JSON Pointer \{pointer} 缺少 equals 断言")
        continue
      }
    }
    match @guardian.resolve_json_pointer(parsed, pointer) {
      Some(actual) if actual == expected => ()
      Some(actual) =>
        failures.push(
          "JSON Pointer \{pointer} 不相等：实际 \{actual.stringify()}，期望 \{expected.stringify()}",
        )
      None => failures.push("JSON Pointer 不存在：\{pointer}")
    }
  }
  failures
}

///|
async fn verify_case(project : String, case : Json) -> Json {
  let id = json_string(case, "id").unwrap_or("unnamed")
  let temp = @fs.tmpdir(prefix="moonbit-guardian-case-")
  defer @fs.rmdir(temp, recursive=true)
  match json_get(case, "fixtures") {
    Some(Array(fixtures)) =>
      for fixture in fixtures {
        match write_fixture(temp, fixture) {
          Some(reason) =>
            return {
              "id": id,
              "status": "invalid_input",
              "failures": [reason],
              "execution": null,
            }
          None => ()
        }
      }
    _ => ()
  }
  let program_raw = match json_string(case, "program") {
    Some(value) => value
    None =>
      return {
        "id": id,
        "status": "invalid_input",
        "failures": ["用例缺少 program"],
        "execution": null,
      }
  }
  let expand = fn(text : String) -> String {
    text
    .replace_all(old="${PROJECT}", new=project)
    .replace_all(old="${TEMP}", new=temp)
  }
  let program = expand(program_raw)
  let command_args = json_strings(case, "args").unwrap_or([]).map(expand)
  let cwd = match json_string(case, "cwd") {
    Some("project") => project
    Some("temp") | None => temp
    Some(path) => expand(path)
  }
  let execution = run_command(
    program,
    command_args,
    cwd,
    stdin_text?=json_string(case, "stdin"),
    timeout_ms=clamp_timeout(json_int(case, "timeout_ms")),
    output_limit=json_int(case, "output_limit").unwrap_or(default_output_limit),
  )
  let failures : Array[String] = []
  if json_string(execution, "status") == Some("timed_out") {
    failures.push("进程超时")
  }
  if json_string(execution, "status") == Some("output_limit_exceeded") {
    failures.push("输出超过上限，不能判定为通过")
  }
  let exit_code = json_int(execution, "exit_code")
  match json_get(case, "exit_code") {
    Some(expectation) => {
      let kind = json_string(expectation, "kind").unwrap_or("zero")
      match exit_code {
        Some(actual) =>
          match
            @guardian.verify_exit_code(
              actual,
              kind,
              exact?=json_int(expectation, "value"),
            ) {
            Some(reason) => failures.push(reason)
            None => ()
          }
        None => failures.push("进程没有可用退出码")
      }
    }
    None => failures.push("用例缺少 exit_code 断言")
  }
  let stdout = json_string(execution, "stdout").unwrap_or("")
  let stderr = json_string(execution, "stderr").unwrap_or("")
  match json_get(case, "stdout") {
    Some(value) =>
      match text_expectation(Some(value)) {
        Some(expected) =>
          failures.append(
            @guardian.verify_text(stdout, expected, stream_name="stdout"),
          )
        None => failures.push("stdout 断言格式无效")
      }
    None => ()
  }
  match json_get(case, "stderr") {
    Some(value) =>
      match text_expectation(Some(value)) {
        Some(expected) =>
          failures.append(
            @guardian.verify_text(stderr, expected, stream_name="stderr"),
          )
        None => failures.push("stderr 断言格式无效")
      }
    None => ()
  }
  failures.append(assert_json_output(stdout, json_get(case, "stdout_json")))
  {
    "id": id,
    "status": if failures.is_empty() {
      "passed"
    } else {
      "failed"
    },
    "failures": failures,
    "execution": execution,
  }
}

///|
async fn verify_contract(args : Json) -> Json {
  let project_requested = json_string(args, "project_path").unwrap_or(".")
  let contract_path = match json_string(args, "contract_path") {
    Some(value) => value
    None =>
      return {
        "status": "invalid_input",
        "toolchain_version": null,
        "cases": [],
        "evidence": ["contract_path 是必填字段"],
        "output_truncated": false,
      }
  }
  if !@fs.exists(project_requested) || !@fs.exists(contract_path) {
    return {
      "status": "invalid_input",
      "toolchain_version": null,
      "cases": [],
      "evidence": ["项目路径或契约文件不存在"],
      "output_truncated": false,
    }
  }
  let project = @fs.realpath(project_requested)
  let document = @fs.read_file(contract_path).json() catch {
    error =>
      return {
        "status": "invalid_input",
        "toolchain_version": null,
        "cases": [],
        "evidence": ["契约不是合法 JSON：\{@debug.to_string(error)}"],
        "output_truncated": false,
      }
  }
  if json_string(document, "version") != Some("1") {
    return {
      "status": "unsupported",
      "toolchain_version": null,
      "cases": [],
      "evidence": ["仅支持契约版本 1"],
      "output_truncated": false,
    }
  }
  let definitions = match json_get(document, "cases") {
    Some(Array(values)) => values
    _ =>
      return {
        "status": "invalid_input",
        "toolchain_version": null,
        "cases": [],
        "evidence": ["cases 必须是数组"],
        "output_truncated": false,
      }
  }
  let results : Array[Json] = []
  let mut passed = 0
  for definition in definitions {
    let result = verify_case(project, definition)
    if json_string(result, "status") == Some("passed") {
      passed += 1
    }
    results.push(result)
  }
  {
    "status": if passed == results.length() {
      "passed"
    } else {
      "failed"
    },
    "toolchain_version": "用例直接执行本地程序；需要时由契约显式调用 moon",
    "contract_version": "1",
    "summary": {
      "total": results.length(),
      "passed": passed,
      "failed": results.length() - passed,
      "unverified": 0,
    },
    "cases": results,
    "scope_note": "通过仅证明契约中声明的用例满足要求，不代表程序绝对正确",
    "evidence": [contract_path, "每个用例在独立临时目录执行"],
    "output_truncated": false,
  }
}

///|
fn tool_definition(
  name : String,
  description : String,
  properties : Json,
  required : Array[String],
) -> Json {
  {
    "name": name,
    "description": description,
    "inputSchema": {
      "type": "object",
      "properties": properties,
      "required": required,
      "additionalProperties": false,
    },
  }
}

///|
fn tool_definitions() -> Array[Json] {
  [
    tool_definition(
      "inspect_moonbit_project",
      "检查 MoonBit 项目、工具链、配置、依赖和缺失条件。",
      { "project_path": { "type": "string" } },
      ["project_path"],
    ),
    tool_definition(
      "get_moonbit_guidance",
      "按主题或诊断码读取经过版本验证的 MoonBit 经验卡片。",
      {
        "project_path": { "type": "string" },
        "topic": { "type": "string" },
        "diagnostic_code": { "type": "string" },
      },
      ["project_path"],
    ),
    tool_definition(
      "lookup_moonbit_api",
      "调用 moon ide doc 查询项目实际可用 API。",
      {
        "project_path": { "type": "string" },
        "symbol": { "type": "string" },
        "timeout_ms": { "type": "integer", "minimum": 1, "maximum": 60000 },
      },
      ["project_path", "symbol"],
    ),
    tool_definition(
      "check_moonbit_code",
      "运行 moon check 或 moon test，并保留原始诊断与退出状态。",
      {
        "project_path": { "type": "string" },
        "mode": { "type": "string", "enum": ["check", "test"] },
        "timeout_ms": { "type": "integer", "minimum": 1, "maximum": 60000 },
      },
      ["project_path", "mode"],
    ),
    tool_definition(
      "verify_delivery_contract",
      "执行版本化 JSON 行为契约，验证 CLI 输入、输出、退出码和 JSON 字段。",
      {
        "project_path": { "type": "string" },
        "contract_path": { "type": "string" },
      },
      ["project_path", "contract_path"],
    ),
  ]
}

///|
fn rpc_response(id : Json, result : Json) -> String {
  let response : Json = { "jsonrpc": "2.0", "id": id, "result": result }
  response.stringify()
}

///|
fn rpc_error(id : Json, code : Int, message : String) -> String {
  let response : Json = {
    "jsonrpc": "2.0",
    "id": id,
    "error": { "code": code, "message": message },
  }
  response.stringify()
}

///|
fn tool_result(payload : Json) -> Json {
  let is_error = match json_string(payload, "status") {
    Some("passed") => false
    _ => true
  }
  {
    "content": [{ "type": "text", "text": payload.stringify(indent=2) }],
    "structuredContent": payload,
    "isError": is_error,
  }
}

///|
async fn call_tool(name : String, arguments : Json) -> Json {
  match name {
    "inspect_moonbit_project" => inspect_project(arguments)
    "get_moonbit_guidance" => get_guidance(arguments)
    "lookup_moonbit_api" => lookup_api(arguments)
    "check_moonbit_code" => check_code(arguments)
    "verify_delivery_contract" => verify_contract(arguments)
    _ =>
      {
        "status": "invalid_input",
        "toolchain_version": null,
        "evidence": ["未知工具：\{name}"],
        "output_truncated": false,
      }
  }
}

///|
async fn handle_message(raw : String) -> String? {
  let message = @json.parse(raw) catch {
    _ => return Some(rpc_error(null, -32700, "Parse error"))
  }
  let id = json_get(message, "id").unwrap_or(null)
  let method_name = match json_string(message, "method") {
    Some(value) => value
    None => return Some(rpc_error(id, -32600, "Invalid Request"))
  }
  match method_name {
    "initialize" =>
      Some(
        rpc_response(id, {
          "protocolVersion": @mcp.latest_protocol_version,
          "capabilities": { "tools": { "listChanged": false } },
          "serverInfo": {
            "name": "moonbit-guardian",
            "title": "MoonBit Guardian",
            "version": @guardian.version,
          },
          "instructions": "先检查项目和查询真实 API，再修改代码；只报告实际执行过的验证。",
        }),
      )
    "notifications/initialized" | "initialized" => None
    "ping" => Some(rpc_response(id, {}))
    "tools/list" => Some(rpc_response(id, { "tools": tool_definitions() }))
    "tools/call" => {
      let params = json_get(message, "params").unwrap_or({})
      let name = match json_string(params, "name") {
        Some(value) => value
        None => return Some(rpc_error(id, -32602, "tools/call 缺少 name"))
      }
      let arguments = json_get(params, "arguments").unwrap_or({})
      let payload = call_tool(name, arguments)
      Some(rpc_response(id, tool_result(payload)))
    }
    _ => Some(rpc_error(id, -32601, "Method not found: \{method_name}"))
  }
}

///|
async fn serve_stdio() -> Unit {
  while @stdio.stdin.read_until("\n") is Some(line) {
    let raw = line.trim().to_owned()
    if !raw.is_empty() {
      match handle_message(raw) {
        Some(response) => @stdio.stdout.write(response + "\n")
        None => ()
      }
    }
  }
}

///|
async fn main {
  let args = @env.args()
  if args.contains("--version") {
    @stdio.stdout.write("moonbit-guardian \{@guardian.version}\n")
  } else if args.contains("--self-test") {
    let result : Json = {
      "status": "passed",
      "version": @guardian.version,
      "protocol_version": @mcp.latest_protocol_version,
    }
    @stdio.stdout.write(result.stringify() + "\n")
  } else {
    serve_stdio()
  }
}
