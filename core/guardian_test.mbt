///|
test "文本断言同时报告缺失与禁止内容" {
  let expected : @guardian.TextExpectation = {
    exact: None,
    contains: ["done"],
    not_contains: ["debug"],
    empty: None,
  }
  let failures = @guardian.verify_text("debug", expected, stream_name="stdout")
  assert_eq(failures.length(), 2)
}

///|
test "退出码断言区分零与非零" {
  assert_eq(@guardian.verify_exit_code(0, "zero"), None)
  assert_true(@guardian.verify_exit_code(2, "zero") is Some(_))
  assert_eq(@guardian.verify_exit_code(2, "exact", exact=2), None)
}

///|
test "JSON Pointer 支持转义、数组与 null" {
  let value : Json = { "a/b": { "~key": [null, { "ok": true }] } }
  assert_eq(
    @guardian.resolve_json_pointer(value, "/a~1b/~0key/1/ok"),
    Some(true),
  )
  assert_eq(@guardian.resolve_json_pointer(value, "/a~1b/~0key/0"), Some(null))
  assert_eq(@guardian.resolve_json_pointer(value, "/missing"), None)
}
