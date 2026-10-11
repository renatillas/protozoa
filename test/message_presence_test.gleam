import gleam/dict
import gleam/list
import gleam/string
import protozoa/decode
import protozoa/encode
import protozoa/internal/codegen
import protozoa/internal/import_resolver
import protozoa/parser/file

pub const schema = "syntax = \"proto3\";
package presence;
enum State {
  UNKNOWN = 0;
  READY = 1;
}
message Child {
  string value = 1;
}
message Empty {
}
message Parent {
  Child child = 1;
  Empty empty = 2;
  optional Child explicit_child = 3;
  repeated Child children = 4;
  map<string, Child> children_by_name = 5;
  State state = 6;
  oneof selection {
    Child selected = 7;
    string label = 8;
  }
}
message Recursive {
  Recursive next = 1;
}
message Outer {
  message Inner {
    string value = 1;
  }
  Inner inner = 1;
}
message Shadow {
  message State {
    string value = 1;
  }
  State state = 1;
}
"

pub fn generated_source() -> String {
  generated_source_from(schema)
}

fn generated_source_from(source_schema: String) -> String {
  let sources =
    dict.from_list([#("presence.proto", import_resolver.Raw(source_schema))])
  let assert Ok(resolver) = import_resolver.resolve(sources, "presence.proto")
  let files =
    import_resolver.get_all_loaded_files(resolver)
    |> list.map(fn(entry) { file.Path(path: entry.0, content: entry.1) })
  let assert Ok(source) =
    codegen.generate(
      files: files,
      registry: import_resolver.get_type_registry(resolver),
    )
  source
}

pub fn presence_only_in_nested_message_imports_option_test() {
  let source =
    generated_source_from(
      "syntax = \"proto3\";
package presence;
message Outer {
  message Inner {
    message Leaf {
    }
    Leaf leaf = 1;
  }
}
",
    )
  assert string.contains(source, "import gleam/option")
  assert string.contains(source, "leaf: option.Option(PresenceOuterInnerLeaf)")
}

pub fn nested_message_shadowing_enum_without_package_preserves_presence_test() {
  let source =
    generated_source_from(
      "syntax = \"proto3\";
enum State {
  UNKNOWN = 0;
}
message Shadow {
  message State {
  }
  State state = 1;
}
",
    )
  assert string.contains(source, "state: option.Option(ShadowState)")
}

pub fn singular_messages_preserve_presence_test() {
  let source = generated_source()
  assert string.contains(source, "child: option.Option(PresenceChild)")
  assert string.contains(source, "empty: option.Option(PresenceEmpty)")
  assert string.contains(source, "decode.optional_nested_message(1,")
  assert string.contains(source, "case presence_parent.child")
}

pub fn recursive_and_nested_messages_preserve_presence_test() {
  let source = generated_source()
  assert string.contains(source, "next: option.Option(PresenceRecursive)")
  assert string.contains(source, "inner: option.Option(PresenceOuterInner)")
  assert string.contains(source, "state: option.Option(PresenceShadowState)")
  assert string.contains(source, "decode.defer(presence_recursive_decoder)")
}

pub fn non_singular_fields_keep_their_existing_shapes_test() {
  let source = generated_source()
  assert string.contains(source, "children: List(PresenceChild)")
  assert string.contains(
    source,
    "children_by_name: List(#(String, PresenceChild))",
  )
  assert string.contains(source, "state: PresenceState")
  assert !string.contains(source, "state: option.Option(PresenceState)")
  assert string.contains(source, "Selected(PresenceChild)")
  assert !string.contains(source, "Selected(option.Option(PresenceChild))")
  assert !string.contains(source, "option.Option(option.Option(")
}

pub fn optional_nested_message_distinguishes_absent_from_empty_test() {
  let decoder = decode.optional_nested_message(1, decode.success(Nil))
  assert decode.run(<<>>, decoder) == Ok(Error(Nil))
  assert decode.run(encode.message_field(1, <<>>), decoder) == Ok(Ok(Nil))
}

pub fn malformed_present_nested_message_is_not_absence_test() {
  let decoder = decode.optional_nested_message(1, decode.success(Nil))
  let assert Error(_) = decode.run(encode.message_field(1, <<128>>), decoder)
  let assert Error(_) = decode.run(encode.int32_field(1, 1), decoder)
}

pub fn malformed_optional_scalar_is_not_absence_test() {
  let decoder = decode.optional_field(1, decode.int32_field)
  assert decode.run(<<>>, decoder) == Ok(Error(Nil))
  assert decode.run(encode.int32_field(1, 0), decoder) == Ok(Ok(0))
  let assert Error(_) = decode.run(encode.string_field(1, "invalid"), decoder)
}

pub fn malformed_oneof_members_do_not_become_absent_test() {
  let source = generated_source()
  assert string.contains(source, "Error(err) -> Error([err])")
  assert !string.contains(source, "Error(_) -> Ok(option.None)")
}
