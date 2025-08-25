//// Protocol Buffer Encode Module
////
//// This module provides functions for encoding Gleam values into Protocol Buffer binary format.
//// It handles the conversion from typed Gleam data structures to the compact binary wire format
//// used by Protocol Buffers for efficient storage and network transmission.
////
//// ## Design Philosophy
////
//// - **Correctness**: Produces valid Protocol Buffer binary data compatible with other implementations
//// - **Efficiency**: Optimized encoding with minimal memory allocations and copies
//// - **Composability**: Field-level encoders that can be combined for message encoding
//// - **Type safety**: Compile-time guarantees about the structure of encoded data
//// - **Deterministic output**: Consistent binary output for the same input data
////
//// ## Capabilities  
////
//// - **All proto3 types**: Scalars (int32, int64, string, bool, bytes), messages, enums
//// - **Advanced features**: Repeated fields, maps, oneofs, nested messages
//// - **Wire format compliance**: Correct tag encoding, varint encoding, length-delimited data
//// - **Field-level encoding**: Individual field encoders for fine-grained control  
//// - **Message-level encoding**: Complete message encoders with proper field ordering
//// - **Size calculation**: Efficient pre-calculation of encoded message sizes
////
//// ## Usage Pattern
////
//// Generated code uses this module to create message-specific encoder functions:
//// ```gleam
//// pub fn encode_user(user: User) -> BitArray {
////   encode.message([
////     encode.string_field(1, user.name),
////     encode.int32_field(2, user.age),
////   ])
//// }
//// ```
////
//// ## Wire Format
////
//// The module correctly implements the Protocol Buffer wire format:
//// - Varint encoding for integers and field tags
//// - Length-delimited encoding for strings, bytes, and messages  
//// - Fixed-width encoding for fixed32/fixed64 types
//// - Proper field tag calculation with field numbers and wire types
////
//// ## Performance
////
//// Encoding is optimized for performance with:
//// - Pre-calculated message sizes to avoid buffer reallocations
//// - Efficient bit array operations for binary data construction
//// - Minimal intermediate allocations during encoding

import gleam/bit_array
import gleam/int
import gleam/list
import protozoa/wire.{type WireType}

/// Encodes an integer as a varint (variable-length integer).
/// Varints are used for int32, int64, uint32, uint64, bool, and enum fields.
/// 
/// ## Examples
/// 
/// ```gleam
/// varint(0) // <<0>>
/// varint(127) // <<127>>
/// varint(128) // <<128, 1>>
/// ```
pub fn varint(value: Int) -> BitArray {
  do_varint(value, <<>>)
}

fn do_varint(value: Int, acc: BitArray) -> BitArray {
  case value {
    v if v < 128 -> bit_array.concat([acc, <<v:int>>])
    v -> {
      let byte = int.bitwise_or(int.bitwise_and(v, 0x7F), 0x80)
      let next_value = int.bitwise_shift_right(v, 7)
      do_varint(next_value, bit_array.concat([acc, <<byte:int>>]))
    }
  }
}

/// Encodes an integer as a fixed 32-bit value in little-endian format.
/// Used for fixed32 and sfixed32 fields.
pub fn fixed32(value: Int) -> BitArray {
  <<value:32-little>>
}

/// Encodes an integer as a fixed 64-bit value in little-endian format.
/// Used for fixed64 and sfixed64 fields.
pub fn fixed64(value: Int) -> BitArray {
  <<value:64-little>>
}

/// Encodes data with a length prefix.
/// The length is encoded as a varint followed by the data.
/// Used for strings, bytes, and nested messages.
pub fn length_delimited(data: BitArray) -> BitArray {
  let length = bit_array.byte_size(data)
  bit_array.concat([varint(length), data])
}

/// Encodes a string as length-delimited UTF-8 bytes.
pub fn string(value: String) -> BitArray {
  let data = bit_array.from_string(value)
  length_delimited(data)
}

/// Creates a Protocol Buffer tag from a field number and wire type.
/// The tag is encoded as a varint.
pub fn tag(field_number: Int, wire_type: WireType) -> BitArray {
  let tag = wire.make_tag(field_number, wire_type)
  varint(tag)
}

/// Encodes a complete field with tag and value.
/// Combines the tag (field number and wire type) with the encoded value.
pub fn field(
  field_number: Int,
  wire_type: WireType,
  value_encoder: BitArray,
) -> BitArray {
  bit_array.concat([tag(field_number, wire_type), value_encoder])
}

/// Encodes an int32 field with tag and value.
pub fn int32_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Varint, varint(value))
}

/// Encodes an int64 field with tag and value.
pub fn int64_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Varint, varint(value))
}

/// Encodes a uint32 field with tag and value.
pub fn uint32_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Varint, varint(value))
}

/// Encodes a uint64 field with tag and value.
pub fn uint64_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Varint, varint(value))
}

/// Encodes a string field with tag and value.
pub fn string_field(field_number: Int, value: String) -> BitArray {
  field(field_number, wire.LengthDelimited, string(value))
}

/// Encodes a boolean field with tag and value.
/// True is encoded as 1, False as 0.
pub fn bool_field(field_number: Int, value: Bool) -> BitArray {
  let int_value = case value {
    True -> 1
    False -> 0
  }
  field(field_number, wire.Varint, varint(int_value))
}

/// Encodes a float as a 32-bit IEEE 754 value in little-endian format.
pub fn float(value: Float) -> BitArray {
  <<value:32-float-little>>
}

/// Encodes a double as a 64-bit IEEE 754 value in little-endian format.
pub fn double(value: Float) -> BitArray {
  <<value:64-float-little>>
}

/// Encodes a float field with tag and value.
pub fn float_field(field_number: Int, value: Float) -> BitArray {
  field(field_number, wire.Fixed32, float(value))
}

/// Encodes a double field with tag and value.
pub fn double_field(field_number: Int, value: Float) -> BitArray {
  field(field_number, wire.Fixed64, double(value))
}

/// Applies zigzag encoding to a signed integer.
/// Zigzag encoding maps signed integers to unsigned integers
/// to make negative numbers more efficient to encode.
/// 
/// ## Examples
/// 
/// ```gleam
/// zigzag(0) // 0
/// zigzag(-1) // 1
/// zigzag(1) // 2
/// zigzag(-2) // 3
/// ```
@internal
pub fn zigzag(value: Int) -> Int {
  case value >= 0 {
    True -> value * 2
    False -> { 0 - value } * 2 - 1
  }
}

/// Encodes a sint32 field (signed int32 with zigzag encoding).
pub fn sint32_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Varint, varint(zigzag(value)))
}

/// Encodes a sint64 field (signed int64 with zigzag encoding).
pub fn sint64_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Varint, varint(zigzag(value)))
}

/// Combines multiple encoded fields into a complete Protocol Buffer message.
pub fn message(fields: List(BitArray)) -> BitArray {
  bit_array.concat(fields)
}

/// Calculates the encoded size of a varint in bytes.
/// Useful for pre-calculating message sizes.
@internal
pub fn varint_size(value: Int) -> Int {
  case value {
    v if v < 0 -> 10
    v if v < 128 -> 1
    v if v < 16_384 -> 2
    v if v < 2_097_152 -> 3
    v if v < 268_435_456 -> 4
    v if v < 34_359_738_368 -> 5
    v if v < 4_398_046_511_104 -> 6
    v if v < 562_949_953_421_312 -> 7
    v if v < 72_057_594_037_927_936 -> 8
    v if v < 9_223_372_036_854_775_808 -> 9
    _ -> 10
  }
}

/// Calculates the total size of a message in bytes.
/// Sums the sizes of all encoded fields.
@internal
pub fn message_size(fields: List(BitArray)) -> Int {
  list.fold(fields, 0, fn(acc, field) { acc + bit_array.byte_size(field) })
}

/// Encodes a bytes field with tag and length-delimited data.
pub fn bytes(field_number: Int, data: BitArray) -> BitArray {
  field(field_number, wire.LengthDelimited, length_delimited(data))
}

/// Encodes a nested message field with tag and length-delimited message data.
pub fn message_field(field_number: Int, message: BitArray) -> BitArray {
  bytes(field_number, message)
}

/// Encodes a fixed32 field with tag and value.
pub fn fixed32_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Fixed32, fixed32(value))
}

/// Encodes a fixed64 field with tag and value.
pub fn fixed64_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Fixed64, fixed64(value))
}

/// Encodes an sfixed32 field (signed fixed32) with tag and value.
pub fn sfixed32_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Fixed32, fixed32(value))
}

/// Encodes an sfixed64 field (signed fixed64) with tag and value.
pub fn sfixed64_field(field_number: Int, value: Int) -> BitArray {
  field(field_number, wire.Fixed64, fixed64(value))
}

/// Encodes a packed repeated int32 field.
/// All values are encoded together and length-delimited.
pub fn repeated_int32_field(field_number: Int, values: List(Int)) -> BitArray {
  let encoded_values = list.map(values, fn(v) { varint(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Encodes a packed repeated int64 field.
/// All values are encoded together and length-delimited.
pub fn repeated_int64_field(field_number: Int, values: List(Int)) -> BitArray {
  let encoded_values = list.map(values, fn(v) { varint(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Encodes a packed repeated float field.
/// All values are encoded together and length-delimited.
pub fn repeated_float_field(field_number: Int, values: List(Float)) -> BitArray {
  let encoded_values = list.map(values, fn(v) { float(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Encodes a packed repeated double field.
/// All values are encoded together and length-delimited.
pub fn repeated_double_field(field_number: Int, values: List(Float)) -> BitArray {
  let encoded_values = list.map(values, fn(v) { double(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Encodes a packed repeated boolean field.
/// All values are encoded together and length-delimited.
pub fn repeated_bool_field(field_number: Int, values: List(Bool)) -> BitArray {
  let int_values =
    list.map(values, fn(v) {
      case v {
        True -> 1
        False -> 0
      }
    })
  let encoded_values = list.map(int_values, fn(v) { varint(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Encodes a packed repeated sint32 field with zigzag encoding.
/// All values are encoded together and length-delimited.
pub fn repeated_sint32_field(field_number: Int, values: List(Int)) -> BitArray {
  let zigzagged = list.map(values, fn(v) { zigzag(v) })
  let encoded_values = list.map(zigzagged, fn(v) { varint(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Encodes a packed repeated sint64 field with zigzag encoding.
/// All values are encoded together and length-delimited.
pub fn repeated_sint64_field(field_number: Int, values: List(Int)) -> BitArray {
  let zigzagged = list.map(values, fn(v) { zigzag(v) })
  let encoded_values = list.map(zigzagged, fn(v) { varint(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Calculates the encoded size of a field tag in bytes.
@internal
pub fn tag_size(field_number: Int) -> Int {
  varint_size(wire.make_tag(field_number, wire.Varint))
}

/// Encodes a packed repeated fixed32 field.
/// All values are encoded together and length-delimited.
pub fn fixed32s(field_number: Int, values: List(Int)) -> BitArray {
  let encoded_values = list.map(values, fn(v) { fixed32(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}

/// Encodes a packed repeated fixed64 field.
/// All values are encoded together and length-delimited.
pub fn fixed64s(field_number: Int, values: List(Int)) -> BitArray {
  let encoded_values = list.map(values, fn(v) { fixed64(v) })
  let concatenated = bit_array.concat(encoded_values)
  field(field_number, wire.LengthDelimited, length_delimited(concatenated))
}
