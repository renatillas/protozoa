import argv
import gleam/io
import gleam/result
import protozoa/codegen
import protozoa/proto_parser
import simplifile

pub fn main() {
  let args = argv.load().arguments

  case args {
    [input_file, output_file] -> {
      case generate_from_proto(input_file, output_file) {
        Ok(_) -> {
          io.println(
            "Successfully generated " <> output_file <> " from " <> input_file,
          )
        }
        Error(err) -> {
          io.println_error("Error: " <> err)
        }
      }
    }
    _ -> {
      io.println("Usage: protozoa <input.proto> <output.gleam>")
      io.println("")
      io.println("Generates Gleam code from Protocol Buffer definitions")
    }
  }
}

pub fn generate_from_proto(
  input_path: String,
  output_path: String,
) -> Result(Nil, String) {
  use proto_content <- result.try(
    simplifile.read(input_path)
    |> result.map_error(fn(_) { "Failed to read proto file: " <> input_path }),
  )

  let proto_file = proto_parser.parse_simple(proto_content)

  let generated_code = codegen.generate_simple(proto_file)

  simplifile.write(output_path, generated_code)
  |> result.map_error(fn(_) { "Failed to write output file: " <> output_path })
}
