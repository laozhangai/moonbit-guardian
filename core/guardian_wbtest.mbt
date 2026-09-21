///|
test "JSON Pointer 非法数组下标不会抛错" {
  assert_eq(resolve_json_pointer([1, 2], "/x"), None)
}
