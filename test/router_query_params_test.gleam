import birdie
import protozoa/internal/codegen
import protozoa/internal/type_registry
import protozoa/parser
import simplifile

pub fn query_parameter_mapping_test() {
  // Read the test proto file
  let assert Ok(proto_content) = simplifile.read("test/test_http_service.proto")

  // Parse it
  let assert Ok(proto_file) = parser.parse(proto_content)

  // Generate code
  let assert Ok([#(_, generated)]) =
    codegen.generate_combined_proto_file(
      files: [
        parser.Path(path: "test/test_http_service.proto", content: proto_file),
      ],
      registry: type_registry.new(),
      output_dir: "test/",
    )
  generated
  |> birdie.snap(title: "HTTP service with query parameter mapping")
}
