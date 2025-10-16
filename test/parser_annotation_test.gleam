import gleam/option.{Some}
import protozoa/parser
import simplifile

pub fn parse_http_annotations_test() {
  let assert Ok(content) = simplifile.read("test/test_http_service.proto")

  let assert Ok(file) = parser.parse(content)

  // Check we parsed messages
  assert file.messages != []

  // Check we parsed services
  assert file.services != []

  // Check the first service
  let assert [service] = file.services
  assert service.name == "TemperatureService"

  // Check methods were parsed
  assert service.methods != []

  // Check first method has HTTP annotation
  let assert [first_method, ..] = service.methods
  assert first_method.name == "GetTemperature"

  // Should have parsed the HTTP method and path from annotation
  case first_method.http_method, first_method.http_path {
    Some(parser.Get), Some(path) -> {
      assert path == "/v1/temperatures/{id}"
    }
    _, _ -> {
      panic as "Expected HTTP method and path to be parsed"
    }
  }
}
