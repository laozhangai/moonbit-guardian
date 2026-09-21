///|
/// MoonBit Guardian 引擎版本。
pub let version : String = "0.1.0"

///|
/// 统一执行状态。工具层用它区分环境缺失、执行失败与验证失败。
pub(all) enum ExecutionStatus {
  Passed
  Failed
  Unsupported
  TimedOut
  OutputLimitExceeded
} derive(Eq, ToJson)

///|
/// 文本流断言。一个规则对象可以同时指定多种约束。
pub(all) struct TextExpectation {
  exact : String?
  contains : Array[String]
  not_contains : Array[String]
  empty : Bool?
} derive(Eq, ToJson, FromJson)

///|
pub fn TextExpectation::empty() -> TextExpectation {
  { exact: None, contains: [], not_contains: [], empty: None, }
}

///|
/// 返回空数组表示所有文本断言通过，否则返回可直接展示的失败原因。
pub fn verify_text(
  actual : String,
  expected : TextExpectation,
  stream_name? : String = "output",
) -> Array[String] {
  let failures : Array[String] = []
  match expected.exact {
    Some(value) if actual != value =>
      failures.push("\{stream_name} 与 exact 期望不一致")
    _ => ()
  }
  for fragment in expected.contains {
    if !actual.contains(fragment) {
      failures.push("\{stream_name} 缺少要求文本：\{fragment}")
    }
  }
  for fragment in expected.not_contains {
    if actual.contains(fragment) {
      failures.push("\{stream_name} 包含禁止文本：\{fragment}")
    }
  }
  match expected.empty {
    Some(true) if !actual.is_empty() =>
      failures.push("\{stream_name} 应为空")
    Some(false) if actual.is_empty() =>
      failures.push("\{stream_name} 不应为空")
    _ => ()
  }
  failures
}

///|
/// 验证退出码约束。`kind` 可取 zero、nonzero 或 exact。
pub fn verify_exit_code(actual : Int, kind : String, exact? : Int) -> String? {
  match kind {
    "zero" if actual != 0 => Some("退出码应为 0，实际为 \{actual}")
    "nonzero" if actual == 0 => Some("退出码应为非零，实际为 0")
    "exact" =>
      match exact {
        Some(value) if actual != value =>
          Some("退出码应为 \{value}，实际为 \{actual}")
        None => Some("exact 退出码断言缺少 value")
        _ => None
      }
    "zero" | "nonzero" => None
    other => Some("不支持的退出码断言：\{other}")
  }
}

///|
fn decode_pointer_segment(segment : String) -> String {
  segment.replace_all(old="~1", new="/").replace_all(old="~0", new="~")
}

///|
/// 按 RFC 6901 解析 JSON Pointer。空指针指向根值。
pub fn resolve_json_pointer(value : Json, pointer : String) -> Json? {
  if pointer.is_empty() {
    return Some(value)
  }
  if !pointer.has_prefix("/") {
    return None
  }
  let mut current = value
  let parts = pointer[1:].split("/").to_array()
  let mut index = 0
  while index < parts.length() {
    let segment = decode_pointer_segment(parts[index].to_owned())
    match current {
      Object(object) =>
        match object.get(segment) {
          Some(next) => current = next
          None => return None
        }
      Array(items) => {
        let item_index = @string.parse_int(segment) catch { _ => return None }
        if item_index < 0 || item_index >= items.length() {
          return None
        }
        current = items[item_index]
      }
      _ => return None
    }
    index += 1
  }
  Some(current)
}
