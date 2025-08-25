import gleam/dict
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit
import protozoa/codegen
import protozoa/internals/import_resolver
import protozoa/parser
import protozoa/internals/type_registry
import protozoa/internals/well_known_types
import simplifile

pub fn main() {
  gleeunit.main()
}

fn create_delete_file(
  name: String,
  proto: String,
  fun: fn() -> b,
) -> Result(Nil, simplifile.FileError) {
  let _ = simplifile.write(name, proto)
  fun()
  let _ = simplifile.delete(name)
}

pub fn new_resolver_test() {
  let assert import_resolver.ImportResolver(
    search_paths: ["."],
    loaded_files:,
    dependency_graph:,
    public_imports:,
    ..,
  ) = import_resolver.new()

  assert 0 == dict.size(loaded_files)
  assert 0 == dict.size(dependency_graph)
  assert 0 == dict.size(public_imports)
}

pub fn with_search_paths_test() {
  let assert import_resolver.ImportResolver(
    search_paths: ["/proto", "/usr/local/include"],
    ..,
  ) =
    import_resolver.new()
    |> import_resolver.with_search_paths(["/proto", "/usr/local/include"])
}

pub fn resolve_simple_file_test() {
  let proto =
    "syntax = \"proto3\";
package test;

message TestMessage {
  string name = 1;
}"
  let file_path = "test_simple.proto"
  use <- create_delete_file(file_path, proto)

  let assert Ok(#(
    parser.ProtoFile(
      syntax: "proto3",
      package: Some("test"),
      imports: [],
      messages: [
        parser.Message(
          name: "TestMessage",
          fields: [
            parser.Field(
              name: "name",
              number: 1,
              field_type: parser.String,
              oneof_name: option.None,
            ),
          ],
          nested_messages: [],
          enums: [],
          oneofs: [],
        ),
      ],
      enums: [],
    ),
    import_resolver,
  )) = import_resolver.new() |> import_resolver.resolve_imports(file_path)

  assert 1 == dict.size(import_resolver.loaded_files)

  let registry = import_resolver.get_type_registry(import_resolver)

  let assert Ok("test.TestMessage") =
    type_registry.resolve_type_reference(registry, "TestMessage", "test")
}

pub fn resolve_with_imports_test() {
  let base_proto =
    "syntax = \"proto3\";
package base;

message BaseMessage {
  string id = 1;
}"

  let dependent_proto =
    "syntax = \"proto3\";
package dependent;

import \"test_base.proto\";

message DependentMessage {
  string name = 1;
}"
  let base_path = "test_base.proto"
  let dependent_path = "test_dependent.proto"
  use <- create_delete_file(base_path, base_proto)
  use <- create_delete_file(dependent_path, dependent_proto)

  let assert Ok(#(
    parser.ProtoFile(package: Some("dependent"), ..),
    updated_resolver,
  )) = import_resolver.new() |> import_resolver.resolve_imports(dependent_path)

  assert 2 == dict.size(updated_resolver.loaded_files)

  let registry = import_resolver.get_type_registry(updated_resolver)

  let assert Ok("base.BaseMessage") =
    type_registry.resolve_type_reference(registry, "BaseMessage", "base")

  let assert Ok("dependent.DependentMessage") =
    type_registry.resolve_type_reference(
      registry,
      "DependentMessage",
      "dependent",
    )
}

pub fn detect_circular_dependency_test() {
  let proto_a =
    "syntax = \"proto3\";
package a;

import \"test_b.proto\";

message MessageA {
  string id = 1;
}"

  let proto_b =
    "syntax = \"proto3\";
package b;

import \"test_a.proto\";

message MessageB {
  string id = 1;
}"
  let test_a_path = "test_a.proto"
  let test_b_path = "test_b.proto"

  use <- create_delete_file(test_a_path, proto_a)
  use <- create_delete_file(test_b_path, proto_b)

  let assert Error(import_resolver.CircularDependency("test_b.proto")) =
    import_resolver.new()
    |> import_resolver.resolve_imports(test_a_path)
}

pub fn resolve_with_search_paths_test() {
  let proto_content =
    "syntax = \"proto3\";
package searchtest;

message SearchTestMessage {
  string name = 1;
}"

  let _ = simplifile.delete("test/proto/search_test.proto")
  let _ = simplifile.create_directory("test/proto")
  let assert Ok(_) =
    simplifile.write("test/proto/search_test.proto", proto_content)

  let resolver =
    import_resolver.new()
    |> import_resolver.with_search_paths(["test/proto"])

  let assert Ok(#(parser.ProtoFile(package: Some("searchtest"), ..), _)) =
    import_resolver.resolve_imports(resolver, "search_test.proto")

  let _ = simplifile.delete("test/proto/search_test.proto")
}

pub fn file_not_found_test() {
  let resolver = import_resolver.new()

  let assert Error(import_resolver.FileNotFound("non_existent_file.proto")) =
    import_resolver.resolve_imports(resolver, "non_existent_file.proto")
}

pub fn get_all_loaded_files_test() {
  let proto1 =
    "syntax = \"proto3\";
package pkg1;

message Message1 {
  string id = 1;
}"

  let proto2 =
    "syntax = \"proto3\";
package pkg2;

import \"test_loaded1.proto\";

message Message2 {
  string name = 1;
}"

  use <- create_delete_file("test_loaded1.proto", proto1)
  use <- create_delete_file("test_loaded2.proto", proto2)

  let assert Ok(#(_, updated_resolver)) =
    import_resolver.new()
    |> import_resolver.resolve_imports("test_loaded2.proto")
  let files = import_resolver.get_all_loaded_files(updated_resolver)

  assert 2 == list.length(files)

  assert ["test_loaded1.proto", "test_loaded2.proto"]
    == files
    |> list.map(fn(entry) { entry.0 })
    |> list.sort(string.compare)
}

pub fn import_syntax_validation_test() {
  let proto_with_comments =
    "syntax = \"proto3\";
package test;

import \"base.proto\"; // this is a comment
import public \"public.proto\"; // public import
import weak \"weak.proto\"; // weak import

message Test {
  string id = 1;
}"

  let parsed = parser.parse(proto_with_comments)

  assert [
      parser.Import(path: "base.proto", public: False, weak: False),
      parser.Import(path: "public.proto", public: True, weak: False),
      parser.Import(path: "weak.proto", public: False, weak: True),
    ]
    == parsed.imports
}

pub fn cross_file_type_resolution_test() {
  let base_proto =
    "syntax = \"proto3\";
package base;

message BaseMessage {
  string id = 1;
}"

  let dependent_proto =
    "syntax = \"proto3\";
package app;

import \"base.proto\";

message AppMessage {
  base.BaseMessage base = 1;
  string name = 2;
}"

  let assert Ok(_) = simplifile.write("base.proto", base_proto)
  let assert Ok(_) = simplifile.write("app.proto", dependent_proto)

  let assert Ok(#(_, updated_resolver)) =
    import_resolver.new()
    |> import_resolver.resolve_imports("app.proto")

  let registry = import_resolver.get_type_registry(updated_resolver)

  // Should resolve base.BaseMessage
  let assert Ok("base.BaseMessage") =
    type_registry.resolve_type_reference(registry, "base.BaseMessage", "app")

  // Should have both messages in registry
  let assert option.Some(_) =
    type_registry.lookup_type(registry, "base.BaseMessage")
  let assert option.Some(_) =
    type_registry.lookup_type(registry, "app.AppMessage")

  let _ = simplifile.delete("base.proto")
  let _ = simplifile.delete("app.proto")
  Nil
}

pub fn public_import_transitivity_test() {
  let a_proto =
    "syntax = \"proto3\";
package a;

message MessageA {
  string id = 1;
}"

  let b_proto =
    "syntax = \"proto3\";
package b;

import public \"a.proto\";

message MessageB {
  string name = 1;
}"

  let c_proto =
    "syntax = \"proto3\";
package c;

import \"b.proto\";

message MessageC {
  a.MessageA a_msg = 1;  // Should be visible through public import
  b.MessageB b_msg = 2;
}"

  let assert Ok(_) = simplifile.write("a.proto", a_proto)
  let assert Ok(_) = simplifile.write("b.proto", b_proto)
  let assert Ok(_) = simplifile.write("c.proto", c_proto)

  let resolver = import_resolver.new()

  let assert Ok(#(_, updated_resolver)) =
    import_resolver.resolve_imports(resolver, "c.proto")

  let public_imports =
    import_resolver.get_public_imports(updated_resolver, "b.proto")

  assert True == list.contains(public_imports, "a.proto")

  let _ = simplifile.delete("a.proto")
  let _ = simplifile.delete("b.proto")
  let _ = simplifile.delete("c.proto")
  Nil
}

// Test nested type references
pub fn nested_type_references_test() {
  let proto =
    "syntax = \"proto3\";
package test;

message Outer {
  message Inner {
    string value = 1;
  }
  
  Inner inner = 1;
}

message Other {
  Outer.Inner nested = 1;
}"

  let parsed = parser.parse(proto)
  let registry = type_registry.new()

  let assert Ok(updated_registry) =
    type_registry.add_file(registry, "test.proto", parsed)

  // Should resolve nested type with dot notation
  assert Ok("test.Outer.Inner")
    == type_registry.resolve_type_reference(
      updated_registry,
      "Outer.Inner",
      "test",
    )

  // Should have nested type in registry
  let assert option.Some(_) =
    type_registry.lookup_type(updated_registry, "test.Outer.Inner")
}

// Test package collision detection
pub fn package_collision_detection_test() {
  let proto1 =
    "syntax = \"proto3\";
package test;

message Duplicate {
  string id = 1;
}"

  let proto2 =
    "syntax = \"proto3\";
package test;

message Duplicate {
  int32 value = 1;
}"

  let parsed1 = parser.parse(proto1)
  let parsed2 = parser.parse(proto2)

  let registry = type_registry.new()

  let assert Ok(updated_registry) =
    type_registry.add_file(registry, "file1.proto", parsed1)

  // Adding the same type from a different file should fail
  let assert Error(type_registry.DuplicateMessageDefinition("test.Duplicate")) =
    type_registry.add_file(updated_registry, "file2.proto", parsed2)
}

// Test well-known types
pub fn well_known_types_test() {
  // Test that well-known types are available
  let well_known_proto_files = well_known_types.get_well_known_proto_files()

  assert 7 == dict.size(well_known_proto_files)

  let assert Ok(parser.ProtoFile(
    package: option.Some("google.protobuf"),
    messages: [parser.Message(name: "Timestamp", ..), ..],
    ..,
  )) = dict.get(well_known_proto_files, "google/protobuf/timestamp.proto")

  let proto_using_wkt =
    "syntax = \"proto3\";
package myapp;

import \"google/protobuf/timestamp.proto\";

message Event {
  string name = 1;
  google.protobuf.Timestamp created_at = 2;
}"

  let assert Ok(_) = simplifile.write("event.proto", proto_using_wkt)

  let resolver = import_resolver.new()

  let assert Ok(#(_, updated_resolver)) =
    import_resolver.resolve_imports(resolver, "event.proto")

  let registry = import_resolver.get_type_registry(updated_resolver)

  let assert option.Some(_) =
    type_registry.lookup_type(registry, "google.protobuf.Timestamp")

  let _ = simplifile.delete("event.proto")
  Nil
}

pub fn field_mask_well_known_type_test() {
  assert True
    == well_known_types.is_well_known_import("google/protobuf/field_mask.proto")

  let proto_using_field_mask =
    "syntax = \"proto3\";
package myapp;

import \"google/protobuf/field_mask.proto\";

message UpdateRequest {
  string id = 1;
  google.protobuf.FieldMask field_mask = 2;
}"

  let assert Ok(_) =
    simplifile.write("update_request.proto", proto_using_field_mask)

  let resolver = import_resolver.new()

  let assert Ok(#(_, updated_resolver)) =
    import_resolver.resolve_imports(resolver, "update_request.proto")

  let registry = import_resolver.get_type_registry(updated_resolver)

  let assert option.Some(_) =
    type_registry.lookup_type(registry, "google.protobuf.FieldMask")

  let _ = simplifile.delete("update_request.proto")
  Nil
}

pub fn test_codegen_with_imports() {
  let base_proto =
    "syntax = \"proto3\";
package base;

enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
}

message BaseMessage {
  string id = 1;
  Status status = 2;
}"

  let app_proto =
    "syntax = \"proto3\";
package app;

import \"base.proto\";

message AppMessage {
  base.BaseMessage base = 1;
  base.Status status = 2;
}"

  let assert Ok(_) = simplifile.write("base.proto", base_proto)
  let assert Ok(_) = simplifile.write("app.proto", app_proto)

  let assert Ok(#(_, updated_resolver)) =
    import_resolver.new() |> import_resolver.resolve_imports("app.proto")

  let files = import_resolver.get_all_loaded_files(updated_resolver)
  let registry = import_resolver.get_type_registry(updated_resolver)

  // Convert to Path type for codegen
  let paths =
    list.map(files, fn(entry) {
      let #(path, content) = entry
      parser.Path(path, content)
    })

  // Test that code generation works with imports
  let assert Ok(generated_files) =
    codegen.generate_with_imports(paths, registry, "./test_output")

  assert 2 == list.length(generated_files)
  // Should generate for both files

  let _ = simplifile.delete("base.proto")
  let _ = simplifile.delete("app.proto")
  let _ = simplifile.delete("./test_output/base.gleam")
  let _ = simplifile.delete("./test_output/app.gleam")
  Nil
}
