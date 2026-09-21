///|
fn main {
  if @env.args().contains("--fail") {
    abort("requested failure")
  }
  println("ready")
}
