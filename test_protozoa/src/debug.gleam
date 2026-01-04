import codegen
import gleam/io

pub fn main() {
  io.println("Generating code files...")
  case codegen.write_all_generated_code(".") {
    Ok(_) -> io.println("Done! Generated files written to src/")
    Error(e) -> io.println("Error: " <> codegen.describe_error(e))
  }
}
