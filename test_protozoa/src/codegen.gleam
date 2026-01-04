/// Code generation for test proto files
///
/// This module generates Gleam code from the proto files in protofiles/
/// and writes them to src/ so they can be compiled and tested.

import gleam/dict
import gleam/result
import protozoa/internal/codegen
import protozoa/internal/import_resolver
import protozoa/parser/file
import simplifile

const base_proto = "syntax = \"proto3\";

package base;

enum BaseStatus {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
}

message BaseMessage {
  string id = 1;
  BaseStatus status = 2;
}
"

const app_proto = "syntax = \"proto3\";

package app;

import \"base.proto\";

message AppMessage {
  base.BaseMessage base = 1;
  base.BaseStatus status = 2;
}
"

const service_proto = "syntax = \"proto3\";

package testservice;

message TestRequest {
  string data = 1;
}

message TestResponse {
  string result = 1;
}

service TestService {
  rpc Process(TestRequest) returns (TestResponse);
}
"

const types_proto = "syntax = \"proto3\";

package types;

message AllTypes {
  double double_field = 1;
  float float_field = 2;
  int32 int32_field = 3;
  int64 int64_field = 4;
  uint32 uint32_field = 5;
  uint64 uint64_field = 6;
  sint32 sint32_field = 7;
  sint64 sint64_field = 8;
  fixed32 fixed32_field = 9;
  fixed64 fixed64_field = 10;
  sfixed32 sfixed32_field = 11;
  sfixed64 sfixed64_field = 12;
  bool bool_field = 13;
  string string_field = 14;
  bytes bytes_field = 15;
}

message RepeatedTypes {
  repeated string strings = 1;
  repeated int32 numbers = 2;
  repeated bool flags = 3;
}

message OptionalTypes {
  optional string maybe_string = 1;
  optional int32 maybe_number = 2;
}

message MapTypes {
  map<string, string> string_map = 1;
  map<int32, string> int_map = 2;
}
"

const nested_proto = "syntax = \"proto3\";

package nested;

message Outer {
  message Inner {
    string value = 1;
  }
  Inner inner = 1;
  repeated Inner items = 2;
}

message Container {
  Outer.Inner nested_inner = 1;
}
"


pub type GenerateError {
  ResolveError(String)
  CodegenError(String)
  WriteError(String)
}

pub fn describe_error(error: GenerateError) -> String {
  case error {
    ResolveError(msg) -> "Resolve error: " <> msg
    CodegenError(msg) -> "Codegen error: " <> msg
    WriteError(msg) -> "Write error: " <> msg
  }
}

/// Generate code for the app + base proto files (tests imports)
pub fn generate_app_code() -> Result(String, GenerateError) {
  let sources =
    dict.new()
    |> dict.insert("base.proto", import_resolver.Raw(base_proto))
    |> dict.insert("app.proto", import_resolver.Raw(app_proto))

  use resolver <- result.try(
    import_resolver.resolve(sources, "app.proto")
    |> result.map_error(fn(e) { ResolveError(import_resolver.describe_error(e)) }),
  )

  let registry = import_resolver.get_type_registry(resolver)
  let files =
    import_resolver.get_all_loaded_files(resolver)
    |> to_paths()

  codegen.generate(files: files, registry: registry)
  |> result.map_error(fn(e) { CodegenError(e) })
}

/// Generate code for the service proto file
pub fn generate_service_code() -> Result(String, GenerateError) {
  let sources =
    dict.new()
    |> dict.insert("service.proto", import_resolver.Raw(service_proto))

  use resolver <- result.try(
    import_resolver.resolve(sources, "service.proto")
    |> result.map_error(fn(e) { ResolveError(import_resolver.describe_error(e)) }),
  )

  let registry = import_resolver.get_type_registry(resolver)
  let files =
    import_resolver.get_all_loaded_files(resolver)
    |> to_paths()

  codegen.generate(files: files, registry: registry)
  |> result.map_error(fn(e) { CodegenError(e) })
}

/// Generate code for the types proto file
pub fn generate_types_code() -> Result(String, GenerateError) {
  let sources =
    dict.new()
    |> dict.insert("types.proto", import_resolver.Raw(types_proto))

  use resolver <- result.try(
    import_resolver.resolve(sources, "types.proto")
    |> result.map_error(fn(e) { ResolveError(import_resolver.describe_error(e)) }),
  )

  let registry = import_resolver.get_type_registry(resolver)
  let files =
    import_resolver.get_all_loaded_files(resolver)
    |> to_paths()

  codegen.generate(files: files, registry: registry)
  |> result.map_error(fn(e) { CodegenError(e) })
}

/// Generate code for the nested proto file
pub fn generate_nested_code() -> Result(String, GenerateError) {
  let sources =
    dict.new()
    |> dict.insert("nested.proto", import_resolver.Raw(nested_proto))

  use resolver <- result.try(
    import_resolver.resolve(sources, "nested.proto")
    |> result.map_error(fn(e) { ResolveError(import_resolver.describe_error(e)) }),
  )

  let registry = import_resolver.get_type_registry(resolver)
  let files =
    import_resolver.get_all_loaded_files(resolver)
    |> to_paths()

  codegen.generate(files: files, registry: registry)
  |> result.map_error(fn(e) { CodegenError(e) })
}

/// Write all generated code to src/ directory
pub fn write_all_generated_code(base_path: String) -> Result(Nil, GenerateError) {
  use app_code <- result.try(generate_app_code())
  use service_code <- result.try(generate_service_code())
  use types_code <- result.try(generate_types_code())
  use nested_code <- result.try(generate_nested_code())

  use _ <- result.try(write_file(base_path <> "/src/generated_app.gleam", app_code))
  use _ <- result.try(write_file(base_path <> "/src/generated_service.gleam", service_code))
  use _ <- result.try(write_file(base_path <> "/src/generated_types.gleam", types_code))
  use _ <- result.try(write_file(base_path <> "/src/generated_nested.gleam", nested_code))

  Ok(Nil)
}

fn write_file(path: String, content: String) -> Result(Nil, GenerateError) {
  simplifile.write(path, content)
  |> result.map_error(fn(_) { WriteError("Failed to write: " <> path) })
}

fn to_paths(loaded_files: List(#(String, file.ProtoFile))) -> List(file.Path) {
  loaded_files
  |> list.map(fn(entry) {
    let #(path, content) = entry
    file.Path(path: path, content: content)
  })
}

import gleam/list
