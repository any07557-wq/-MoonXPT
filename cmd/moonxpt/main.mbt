///|
extern "C" fn platform_probe() -> Int32 = "moonxpt_platform_probe"

///|
fn main {
  println(
    "MoonXPT V5 / record=\{@xpt.RECORD_SIZE} / native=\{platform_probe()}",
  )
}
