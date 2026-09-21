///|
fn main {
  let values = [1, 2, 3]
  let total = values.fold(init=0, (sum, value) => sum + value)
  println("sum=\{total}")
}
