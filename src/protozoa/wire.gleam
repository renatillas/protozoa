import gleam/int

/// WireType represents the encoding format used for Protocol Buffer fields.
/// Each wire type determines how the field value is encoded on the wire.
pub type WireType {
  /// Variable-length encoding for integers (int32, int64, uint32, uint64, sint32, sint64, bool, enum)
  Varint
  /// Fixed 64-bit value (fixed64, sfixed64, double)
  Fixed64
  /// Length-prefixed data (string, bytes, embedded messages, packed repeated fields)
  LengthDelimited
  /// Deprecated: Start of a group (no longer used in proto3)
  StartGroup
  /// Deprecated: End of a group (no longer used in proto3)
  EndGroup
  /// Fixed 32-bit value (fixed32, sfixed32, float)
  Fixed32
}

/// Converts a WireType to its corresponding integer value used in Protocol Buffer tags.
/// Returns:
/// - 0 for Varint
/// - 1 for Fixed64
/// - 2 for LengthDelimited
/// - 3 for StartGroup (deprecated)
/// - 4 for EndGroup (deprecated)
/// - 5 for Fixed32
pub fn wire_type_value(wire_type: WireType) -> Int {
  case wire_type {
    Varint -> 0
    Fixed64 -> 1
    LengthDelimited -> 2
    StartGroup -> 3
    EndGroup -> 4
    Fixed32 -> 5
  }
}

/// Converts an integer value to its corresponding WireType.
/// Returns Error if the value is not a valid wire type (0-5).
/// 
/// ## Examples
/// 
/// ```gleam
/// wire_type_from_int(0) // Ok(Varint)
/// wire_type_from_int(2) // Ok(LengthDelimited)
/// wire_type_from_int(7) // Error("Invalid wire type: 7")
/// ```
pub fn wire_type_from_int(value: Int) -> Result(WireType, String) {
  case value {
    0 -> Ok(Varint)
    1 -> Ok(Fixed64)
    2 -> Ok(LengthDelimited)
    3 -> Ok(StartGroup)
    4 -> Ok(EndGroup)
    5 -> Ok(Fixed32)
    _ -> Error("Invalid wire type: " <> int.to_string(value))
  }
}

/// Creates a Protocol Buffer tag from a field number and wire type.
/// The tag is encoded as (field_number << 3) | wire_type.
/// 
/// ## Examples
/// 
/// ```gleam
/// make_tag(1, Varint) // Returns 8 (field 1 with wire type 0)
/// make_tag(2, LengthDelimited) // Returns 18 (field 2 with wire type 2)
/// ```
pub fn make_tag(field_number: Int, wire_type: WireType) -> Int {
  int.bitwise_shift_left(field_number, 3)
  |> int.bitwise_or(wire_type_value(wire_type))
}

/// Extracts the field number from a Protocol Buffer tag.
/// The field number is stored in the upper bits (tag >> 3).
/// 
/// ## Examples
/// 
/// ```gleam
/// get_field_number(8) // Returns 1
/// get_field_number(18) // Returns 2
/// ```
pub fn get_field_number(tag: Int) -> Int {
  int.bitwise_shift_right(tag, 3)
}

/// Extracts the wire type from a Protocol Buffer tag.
/// The wire type is stored in the lower 3 bits (tag & 7).
/// Returns Error if the extracted value is not a valid wire type.
/// 
/// ## Examples
/// 
/// ```gleam
/// get_wire_type(8) // Ok(Varint)
/// get_wire_type(18) // Ok(LengthDelimited)
/// ```
pub fn get_wire_type(tag: Int) -> Result(WireType, String) {
  int.bitwise_and(tag, 7)
  |> wire_type_from_int
}
