import birdie
import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import protozoa/internal/codegen
import protozoa/internal/import_resolver
import protozoa/internal/type_registry
import protozoa/internal/well_known_type
import protozoa/parser/file
import protozoa/parser/proto

// ============================================================================
// Basic resolver tests
// ============================================================================

pub fn new_resolver_test() {
  let import_resolver.ImportResolver(
    loaded_files:,
    dependency_graph:,
    public_imports:,
    ..,
  ) = import_resolver.new()

  assert 0 == dict.size(loaded_files)
  assert 0 == dict.size(dependency_graph)
  assert 0 == dict.size(public_imports)
}

pub fn resolve_simple_file_test() {
  let proto =
    "syntax = \"proto3\";
package test;

message TestMessage {
  string name = 1;
}"

  let sources = dict.from_list([#("test.proto", import_resolver.Raw(proto))])

  let assert Ok(resolver) = import_resolver.resolve(sources, "test.proto")

  assert 1 == dict.size(resolver.loaded_files)

  let registry = import_resolver.get_type_registry(resolver)

  let assert Ok("test.TestMessage") =
    type_registry.resolve_type_reference(registry, "TestMessage", "test")
}

pub fn resolve_with_imports_test() {
  let base_proto =
    "
syntax = \"proto3\";
package base;

message BaseMessage {
  string id = 1;
}"

  let dependent_proto =
    "syntax = \"proto3\";
package dependent;

import \"base.proto\";

message DependentMessage {
  string name = 1;
}"

  let sources =
    dict.from_list([
      #("base.proto", import_resolver.Raw(base_proto)),
      #("dependent.proto", import_resolver.Raw(dependent_proto)),
    ])

  let assert Ok(resolver) = import_resolver.resolve(sources, "dependent.proto")

  assert 2 == dict.size(resolver.loaded_files)

  let registry = import_resolver.get_type_registry(resolver)

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

import \"b.proto\";

message MessageA {
  string id = 1;
}"

  let proto_b =
    "syntax = \"proto3\";
package b;

import \"a.proto\";

message MessageB {
  string id = 1;
}"

  let sources =
    dict.from_list([
      #("a.proto", import_resolver.Raw(proto_a)),
      #("b.proto", import_resolver.Raw(proto_b)),
    ])

  let assert Error(import_resolver.CircularDependency("a.proto")) =
    import_resolver.resolve(sources, "a.proto")
}

pub fn file_not_found_test() {
  let sources = dict.new()

  let assert Error(import_resolver.FileNotFound("non_existent_file.proto")) =
    import_resolver.resolve(sources, "non_existent_file.proto")
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

import \"file1.proto\";

message Message2 {
  string name = 1;
}"

  let sources =
    dict.from_list([
      #("file1.proto", import_resolver.Raw(proto1)),
      #("file2.proto", import_resolver.Raw(proto2)),
    ])

  let assert Ok(resolver) = import_resolver.resolve(sources, "file2.proto")
  let files = import_resolver.get_all_loaded_files(resolver)

  assert 2 == list.length(files)

  assert ["file1.proto", "file2.proto"]
    == files
    |> list.map(fn(entry) { entry.0 })
    |> list.sort(string.compare)
}

// ============================================================================
// Import syntax tests
// ============================================================================

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

  let assert Ok(parsed) = file.parse(proto_with_comments)

  assert [
      proto.Import(path: "base.proto", public: False, weak: False),
      proto.Import(path: "public.proto", public: True, weak: False),
      proto.Import(path: "weak.proto", public: False, weak: True),
    ]
    == parsed.imports
}

// ============================================================================
// Cross-file type resolution tests
// ============================================================================

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

  let sources =
    dict.from_list([
      #("base.proto", import_resolver.Raw(base_proto)),
      #("app.proto", import_resolver.Raw(dependent_proto)),
    ])

  let assert Ok(resolver) = import_resolver.resolve(sources, "app.proto")

  let registry = import_resolver.get_type_registry(resolver)

  // Should resolve base.BaseMessage
  let assert Ok("base.BaseMessage") =
    type_registry.resolve_type_reference(registry, "base.BaseMessage", "app")

  // Should have both messages in registry
  let assert option.Some(_) =
    type_registry.lookup_type(registry, "base.BaseMessage")
  let assert option.Some(_) =
    type_registry.lookup_type(registry, "app.AppMessage")
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

  let sources =
    dict.from_list([
      #("a.proto", import_resolver.Raw(a_proto)),
      #("b.proto", import_resolver.Raw(b_proto)),
      #("c.proto", import_resolver.Raw(c_proto)),
    ])

  let assert Ok(resolver) = import_resolver.resolve(sources, "c.proto")

  let public_imports = import_resolver.get_public_imports(resolver, "b.proto")

  assert True == list.contains(public_imports, "a.proto")
}

// ============================================================================
// Nested type tests
// ============================================================================

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

  let assert Ok(parsed) = file.parse(proto)
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

// ============================================================================
// Type collision tests
// ============================================================================

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

  let assert Ok(parsed1) = file.parse(proto1)
  let assert Ok(parsed2) = file.parse(proto2)

  let registry = type_registry.new()

  let assert Ok(updated_registry) =
    type_registry.add_file(registry, "file1.proto", parsed1)

  // Adding the same type from a different file should fail
  let assert Error(type_registry.DuplicateMessageDefinition("test.Duplicate")) =
    type_registry.add_file(updated_registry, "file2.proto", parsed2)
}

// ============================================================================
// Well-known types tests
// ============================================================================

pub fn well_known_types_availability_test() {
  let well_known_proto_files = well_known_type.get_well_known_proto_files()

  assert 12 == dict.size(well_known_proto_files)

  let assert Ok(file.ProtoFile(
    package: option.Some("google.protobuf"),
    messages: [proto.Message(name: "Timestamp", ..), ..],
    ..,
  )) = dict.get(well_known_proto_files, "google/protobuf/timestamp.proto")
}

pub fn well_known_types_resolution_test() {
  let proto_using_wkt =
    "syntax = \"proto3\";
package myapp;

import \"google/protobuf/timestamp.proto\";

message Event {
  string name = 1;
  google.protobuf.Timestamp created_at = 2;
}"

  let sources =
    dict.from_list([#("event.proto", import_resolver.Raw(proto_using_wkt))])

  let assert Ok(resolver) = import_resolver.resolve(sources, "event.proto")

  let registry = import_resolver.get_type_registry(resolver)

  assert option.Some(#(
      "google/protobuf/timestamp.proto",
      proto.MessageType("Timestamp"),
    ))
    == type_registry.lookup_type(registry, "google.protobuf.Timestamp")
}

pub fn field_mask_well_known_type_test() {
  assert True
    == well_known_type.is_well_known_import("google/protobuf/field_mask.proto")

  let proto_using_field_mask =
    "syntax = \"proto3\";
package myapp;

import \"google/protobuf/field_mask.proto\";

message UpdateRequest {
  string id = 1;
  google.protobuf.FieldMask field_mask = 2;
}"

  let sources =
    dict.from_list([
      #("update_request.proto", import_resolver.Raw(proto_using_field_mask)),
    ])

  let assert Ok(resolver) =
    import_resolver.resolve(sources, "update_request.proto")

  let registry = import_resolver.get_type_registry(resolver)

  let assert option.Some(_) =
    type_registry.lookup_type(registry, "google.protobuf.FieldMask")
}

// ============================================================================
// Service parsing tests
// ============================================================================

pub fn service_parsing_test() {
  let service_proto =
    "syntax = \"proto3\";
package testservice;

message GetUserRequest {
  string user_id = 1;
}

message GetUserResponse {
  string name = 1;
  string email = 2;
}

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc StreamUsers(GetUserRequest) returns (stream GetUserResponse);
  rpc UploadData(stream GetUserRequest) returns (GetUserResponse);
  rpc Chat(stream GetUserRequest) returns (stream GetUserResponse);
}"

  let assert Ok(parsed) = file.parse(service_proto)

  // Should have one service
  assert 1 == list.length(parsed.services)

  let assert [service] = parsed.services
  assert "UserService" == service.name
  assert 4 == list.length(service.methods)

  // Check each method
  let assert [get_user, stream_users, upload_data, chat] = service.methods

  // GetUser - simple unary
  assert "GetUser" == get_user.name
  assert "GetUserRequest" == get_user.input_type
  assert "GetUserResponse" == get_user.output_type
  assert False == get_user.client_streaming
  assert False == get_user.server_streaming

  // StreamUsers - server streaming
  assert "StreamUsers" == stream_users.name
  assert False == stream_users.client_streaming
  assert True == stream_users.server_streaming

  // UploadData - client streaming
  assert "UploadData" == upload_data.name
  assert True == upload_data.client_streaming
  assert False == upload_data.server_streaming

  // Chat - bidirectional streaming
  assert "Chat" == chat.name
  assert True == chat.client_streaming
  assert True == chat.server_streaming
}

// ============================================================================
// Code generation snapshot tests
// ============================================================================

pub fn codegen_simple_message_test() {
  let proto =
    "syntax = \"proto3\";
package test;

message SimpleMessage {
  string name = 1;
  int32 value = 2;
}"

  let sources = dict.from_list([#("test.proto", import_resolver.Raw(proto))])

  let assert Ok(resolver) = import_resolver.resolve(sources, "test.proto")

  let files = import_resolver.get_all_loaded_files(resolver)
  let registry = import_resolver.get_type_registry(resolver)

  let paths =
    list.map(files, fn(entry) {
      let #(path, content) = entry
      file.Path(path, content)
    })

  let assert Ok(generated) = codegen.generate(files: paths, registry: registry)

  generated
  |> birdie.snap(title: "Simple message code generation")
}

pub fn codegen_with_imports_test() {
  let base_proto =
    "syntax = \"proto3\";
package base;

enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
}

message Message {
  string id = 1;
  Status status = 2;
}"

  let app_proto =
    "syntax = \"proto3\";
package app;

import \"base.proto\";

message Message {
  base.Message base = 1;
  base.Status status = 2;
}"

  let sources =
    dict.from_list([
      #("base.proto", import_resolver.Raw(base_proto)),
      #("app.proto", import_resolver.Raw(app_proto)),
    ])

  let assert Ok(resolver) = import_resolver.resolve(sources, "app.proto")

  let files = import_resolver.get_all_loaded_files(resolver)
  let registry = import_resolver.get_type_registry(resolver)

  let paths =
    list.map(files, fn(entry) {
      let #(path, content) = entry
      file.Path(path, content)
    })

  let assert Ok(generated) = codegen.generate(files: paths, registry: registry)

  generated
  |> birdie.snap(title: "Code generation with imports")
}

pub fn codegen_service_test() {
  let service_proto =
    "syntax = \"proto3\";
package testservice;

message Request {
  string data = 1;
}

message Response {
  string result = 1;
}

service TestService {
  rpc Process(Request) returns (Response);
}"

  let sources =
    dict.from_list([#("service.proto", import_resolver.Raw(service_proto))])

  let assert Ok(resolver) = import_resolver.resolve(sources, "service.proto")

  let files = import_resolver.get_all_loaded_files(resolver)
  let registry = import_resolver.get_type_registry(resolver)

  let paths =
    list.map(files, fn(entry) {
      let #(path, content) = entry
      file.Path(path, content)
    })

  let assert Ok(generated) = codegen.generate(files: paths, registry: registry)

  generated
  |> birdie.snap(title: "Service code generation")
}
