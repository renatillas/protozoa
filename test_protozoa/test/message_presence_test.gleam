import generated_presence as messages
import gleam/option.{None, Some}

pub fn absent_messages_roundtrip_test() {
  let message = messages.PresenceParent(None, None, None)
  assert messages.encode_presence_parent(message) == <<>>
  assert messages.decode_presence_parent(<<>>) == Ok(message)
}

pub fn present_empty_message_has_distinct_wire_presence_test() {
  let message =
    messages.PresenceParent(None, Some(messages.PresenceEmpty), None)
  assert messages.encode_presence_parent(message) == <<18, 0>>
  assert messages.decode_presence_parent(<<18, 0>>) == Ok(message)
  assert messages.decode_presence_parent(<<>>) != Ok(message)
}

pub fn present_populated_message_roundtrip_test() {
  let message =
    messages.PresenceParent(Some(messages.PresenceChild("ok")), None, None)
  assert messages.encode_presence_parent(message) == <<10, 4, 10, 2, 111, 107>>
  assert messages.decode_presence_parent(<<10, 4, 10, 2, 111, 107>>)
    == Ok(message)
}

pub fn explicitly_optional_message_retains_presence_test() {
  let message =
    messages.PresenceParent(None, None, Some(messages.PresenceChild("ok")))
  assert messages.encode_presence_parent(message) == <<26, 4, 10, 2, 111, 107>>
  assert messages.decode_presence_parent(<<26, 4, 10, 2, 111, 107>>)
    == Ok(message)
}

pub fn recursive_message_can_terminate_with_absence_test() {
  let message =
    messages.PresenceRecursive(Some(messages.PresenceRecursive(None)))
  assert messages.encode_presence_recursive(message) == <<10, 0>>
  assert messages.decode_presence_recursive(<<10, 0>>) == Ok(message)
}

pub fn mutually_recursive_messages_decode_without_eager_recursion_test() {
  let message = messages.PresenceMutualA(Some(messages.PresenceMutualB(None)))
  assert messages.encode_presence_mutual_a(message) == <<10, 0>>
  assert messages.decode_presence_mutual_a(<<10, 0>>) == Ok(message)
  assert messages.decode_presence_mutual_a(<<>>)
    == Ok(messages.PresenceMutualA(None))
}

pub fn nested_empty_message_retains_presence_test() {
  let message = messages.PresenceNested(Some(messages.PresenceNestedLeaf))
  assert messages.encode_presence_nested(message) == <<10, 0>>
  assert messages.decode_presence_nested(<<10, 0>>) == Ok(message)
}

pub fn nested_message_shadowing_enum_retains_presence_test() {
  let message =
    messages.PresenceShadow(Some(messages.PresenceShadowState), None)
  assert messages.encode_presence_shadow(message) == <<10, 0>>
  assert messages.decode_presence_shadow(<<10, 0>>) == Ok(message)
  let explicit =
    messages.PresenceShadow(None, Some(messages.PresenceShadowState))
  assert messages.encode_presence_shadow(explicit) == <<18, 0>>
  assert messages.decode_presence_shadow(<<18, 0>>) == Ok(explicit)
  assert messages.decode_presence_shadow(<<>>)
    == Ok(messages.PresenceShadow(None, None))
}

pub fn malformed_present_messages_are_rejected_test() {
  let assert Error(_) = messages.decode_presence_parent(<<10, 1, 128>>)
  let assert Error(_) = messages.decode_presence_parent(<<8, 1>>)
  let assert Error(_) = messages.decode_presence_parent(<<26, 1, 128>>)
}

pub fn oneof_empty_message_is_selected_not_absent_test() {
  let message =
    messages.PresenceChoice(Some(messages.Empty(messages.PresenceEmpty)))
  assert messages.encode_presence_choice(message) == <<10, 0>>
  assert messages.decode_presence_choice(<<10, 0>>) == Ok(message)
  assert messages.decode_presence_choice(<<>>)
    == Ok(messages.PresenceChoice(None))
}

pub fn malformed_present_oneof_members_are_rejected_test() {
  let assert Error(_) = messages.decode_presence_choice(<<10, 1, 128>>)
  let assert Error(_) = messages.decode_presence_choice(<<18, 1, 128>>)
  let assert Error(_) = messages.decode_presence_choice(<<8, 1>>)
}

pub fn single_member_oneof_preserves_presence_and_rejects_malformed_data_test() {
  let message =
    messages.PresenceSingleChoice(Some(messages.Only(messages.PresenceEmpty)))
  assert messages.encode_presence_single_choice(message) == <<10, 0>>
  assert messages.decode_presence_single_choice(<<10, 0>>) == Ok(message)
  assert messages.decode_presence_single_choice(<<>>)
    == Ok(messages.PresenceSingleChoice(None))
  let assert Error(_) = messages.decode_presence_single_choice(<<10, 1, 128>>)
  let assert Error(_) = messages.decode_presence_single_choice(<<8, 1>>)
}

pub fn repeated_and_map_message_values_are_not_optional_test() {
  let message =
    messages.PresenceCollection(
      items: [messages.PresenceEmpty, messages.PresenceEmpty],
      values: [#("first", messages.PresenceEmpty)],
    )
  let bytes = messages.encode_presence_collection(message)
  assert messages.decode_presence_collection(bytes) == Ok(message)
  assert messages.decode_presence_collection(<<>>)
    == Ok(messages.PresenceCollection([], []))
}
