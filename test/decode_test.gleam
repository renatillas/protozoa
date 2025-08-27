import gleeunit
import protozoa/decode

pub fn main() {
  gleeunit.main()
}

pub fn simple_test() {
  let decoder = decode.success(42)
  assert decode.run(<<>>, decoder) == Ok(42)
}
