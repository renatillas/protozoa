/// A decoder module following the gleam/dynamic/decode pattern.
/// This provides a composable, type-safe API for decoding protobuf messages.
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gloto/wire.{type WireType}

// Core types

/// Represents an error that occurred during decoding.
/// Contains a descriptive error message.
pub type DecodeError {
  DecodeError(message: String)
  FieldNotFound(field_number: Int)
}

/// Represents a decoded Protocol Buffer field.
/// Contains the field number, wire type, and raw data.
pub type Field {
  Field(number: Int, wire_type: WireType, data: BitArray)
}

/// Represents a decoded Protocol Buffer value.
/// Can be a message, varint, fixed32, fixed64, or length-delimited data.
pub type ProtoValue {
  ProtoMessage(List(Field))
  ProtoVarint(Int)
  ProtoFixed32(BitArray)
  ProtoFixed64(BitArray)
  ProtoLengthDelimited(BitArray)
}

/// A decoder is a function that takes a list of fields and produces a value.
/// This type allows for composable, type-safe decoding of Protocol Buffer messages.
pub opaque type Decoder(a) {
  Decoder(fn(List(Field)) -> Result(a, DecodeError))
}

/// Run a decoder on a BitArray containing Protocol Buffer data.
/// 
/// ## Examples
/// 
/// ```gleam
/// let decoder = field(1, varint_field)
/// decode(<<8, 42>>, decoder) // Decodes field 1 with value 42
/// ```
pub fn decode(
  data: BitArray,
  with decoder: Decoder(a),
) -> Result(a, DecodeError) {
  use fields <- result.try(decode_message(data))
  let Decoder(f) = decoder
  f(fields)
}

/// Create a decoder that always succeeds with a value.
/// Useful for providing default values or building complex decoders.
/// 
/// ## Examples
/// 
/// ```gleam
/// success(42) // Always returns Ok(42)
/// ```
pub fn success(value: a) -> Decoder(a) {
  Decoder(fn(_fields) { Ok(value) })
}

/// Create a decoder that always fails with an error message.
/// Useful for handling unsupported fields or validation errors.
/// 
/// ## Examples
/// 
/// ```gleam
/// fail("Unsupported field type") // Always returns Error
/// ```
pub fn fail(error: String) -> Decoder(a) {
  Decoder(fn(_fields) { Error(DecodeError(error)) })
}

/// Decode a required field with a specific decoder.
/// Returns an error if the field is not present.
/// 
/// ## Examples
/// 
/// ```gleam
/// field(1, varint_field) // Decodes field 1 as a varint
/// field(2, string_field) // Decodes field 2 as a string
/// ```
pub fn field(
  number: Int,
  decoder: fn(Field) -> Result(a, DecodeError),
) -> Decoder(a) {
  Decoder(fn(fields) {
    case list.find(fields, fn(f: Field) { f.number == number }) {
      Ok(field) -> decoder(field)
      Error(_) -> Error(FieldNotFound(number))
    }
  })
}

/// Decode an optional field.
/// Returns Ok(Ok(value)) if the field is present and valid,
/// Ok(Error(Nil)) if the field is missing or invalid.
/// 
/// ## Examples
/// 
/// ```gleam
/// optional_field(1, varint_field) // Decodes optional field 1
/// ```
pub fn optional_field(
  number: Int,
  decoder: fn(Field) -> Result(a, DecodeError),
) -> Decoder(Result(a, Nil)) {
  Decoder(fn(fields) {
    case list.find(fields, fn(f: Field) { f.number == number }) {
      Ok(field) -> {
        case decoder(field) {
          Ok(value) -> Ok(Ok(value))
          Error(_) -> Ok(Error(Nil))
        }
      }
      Error(_) -> Ok(Error(Nil))
    }
  })
}

/// Decode a field with a default value.
/// Returns the decoded value if present, otherwise returns the default.
/// 
/// ## Examples
/// 
/// ```gleam
/// field_with_default(1, varint_field, 0) // Returns 0 if field 1 is missing
/// ```
pub fn field_with_default(
  number: Int,
  decoder: fn(Field) -> Result(a, DecodeError),
  default: a,
) -> Decoder(a) {
  Decoder(fn(fields) {
    case list.find(fields, fn(f: Field) { f.number == number }) {
      Ok(field) -> {
        case decoder(field) {
          Ok(value) -> Ok(value)
          Error(_) -> Ok(default)
        }
      }
      Error(_) -> Ok(default)
    }
  })
}

/// Decode all fields with a given number (for repeated fields).
/// Returns a list of all decoded values for the field number.
/// 
/// ## Examples
/// 
/// ```gleam
/// repeated_field(1, varint_field) // Decodes all field 1 occurrences
/// ```
pub fn repeated_field(
  number: Int,
  decoder: fn(Field) -> Result(a, DecodeError),
) -> Decoder(List(a)) {
  Decoder(fn(fields) {
    fields
    |> list.filter(fn(f: Field) { f.number == number })
    |> list.try_map(decoder)
  })
}

// Type-specific field decoders

/// Decodes a varint field to an integer.
/// Used for int32, int64, uint32, uint64, bool, and enum fields.
pub fn varint_field(field: Field) -> Result(Int, DecodeError) {
  case field.wire_type {
    wire.Varint -> {
      case field.data {
        <<value:64>> -> Ok(value)
        _ -> Error(DecodeError("Invalid varint data"))
      }
    }
    _ -> Error(DecodeError("Field is not a varint"))
  }
}

/// Decodes a length-delimited field as a UTF-8 string.
pub fn string_field(field: Field) -> Result(String, DecodeError) {
  case field.wire_type {
    wire.LengthDelimited -> {
      bit_array.to_string(field.data)
      |> result.map_error(fn(_) { DecodeError("Invalid UTF-8 string") })
    }
    _ -> Error(DecodeError("Field is not length-delimited"))
  }
}

/// Decodes a length-delimited field as raw bytes.
pub fn bytes_field(field: Field) -> Result(BitArray, DecodeError) {
  case field.wire_type {
    wire.LengthDelimited -> Ok(field.data)
    _ -> Error(DecodeError("Field is not length-delimited"))
  }
}

/// Decodes a fixed32 field as a float.
pub fn float_field(field: Field) -> Result(Float, DecodeError) {
  case field.wire_type {
    wire.Fixed32 -> {
      case field.data {
        <<value:32-float-little>> -> Ok(value)
        _ -> Error(DecodeError("Invalid float data"))
      }
    }
    _ -> Error(DecodeError("Field is not a float"))
  }
}

/// Decodes a fixed64 field as a double (Float in Gleam).
pub fn double_field(field: Field) -> Result(Float, DecodeError) {
  case field.wire_type {
    wire.Fixed64 -> {
      case field.data {
        <<value:64-float-little>> -> Ok(value)
        _ -> Error(DecodeError("Invalid double data"))
      }
    }
    _ -> Error(DecodeError("Field is not a double"))
  }
}

/// Decodes a varint field as a boolean (0 = false, non-zero = true).
pub fn bool_field(field: Field) -> Result(Bool, DecodeError) {
  use value <- result.try(varint_field(field))
  Ok(value != 0)
}

/// Decodes a fixed32 field as an integer.
pub fn fixed32_int_field(field: Field) -> Result(Int, DecodeError) {
  case field.wire_type {
    wire.Fixed32 -> {
      case field.data {
        <<value:32-little>> -> Ok(value)
        _ -> Error(DecodeError("Invalid fixed32 data"))
      }
    }
    _ -> Error(DecodeError("Field is not a fixed32"))
  }
}

/// Decodes a fixed64 field as an integer.
pub fn fixed64_int_field(field: Field) -> Result(Int, DecodeError) {
  case field.wire_type {
    wire.Fixed64 -> {
      case field.data {
        <<value:64-little>> -> Ok(value)
        _ -> Error(DecodeError("Invalid fixed64 data"))
      }
    }
    _ -> Error(DecodeError("Field is not a fixed64"))
  }
}

/// Decodes an sfixed32 field as a signed integer.
pub fn sfixed32_field(field: Field) -> Result(Int, DecodeError) {
  case field.wire_type {
    wire.Fixed32 -> {
      case field.data {
        <<value:32-signed-little>> -> Ok(value)
        _ -> Error(DecodeError("Invalid sfixed32 data"))
      }
    }
    _ -> Error(DecodeError("Field is not an sfixed32"))
  }
}

/// Decodes an sfixed64 field as a signed integer.
pub fn sfixed64_field(field: Field) -> Result(Int, DecodeError) {
  case field.wire_type {
    wire.Fixed64 -> {
      case field.data {
        <<value:64-signed-little>> -> Ok(value)
        _ -> Error(DecodeError("Invalid sfixed64 data"))
      }
    }
    _ -> Error(DecodeError("Field is not an sfixed64"))
  }
}

/// Decodes a nested message field using the provided decoder.
pub fn message_field(
  field: Field,
  decoder: Decoder(a),
) -> Result(a, DecodeError) {
  use bytes <- result.try(bytes_field(field))
  use inner_fields <- result.try(decode_message(bytes))
  let Decoder(f) = decoder
  f(inner_fields)
}

// Convenience decoders combining field number and type

/// Decoder for int32 fields.
pub fn int32(number: Int) -> Decoder(Int) {
  field(number, varint_field)
}

/// Decoder for int32 fields with a default value.
pub fn int32_with_default(number: Int, default: Int) -> Decoder(Int) {
  field_with_default(number, varint_field, default)
}

pub fn int64_with_default(number: Int, default: Int) -> Decoder(Int) {
  field_with_default(number, varint_field, default)
}

/// Decoder for int64 fields.
pub fn int64(number: Int) -> Decoder(Int) {
  field(number, varint_field)
}

/// Decoder for uint32 fields.
pub fn uint32(number: Int) -> Decoder(Int) {
  field(number, varint_field)
}

/// Decoder for uint32 fields with a default value.
pub fn uint32_with_default(number: Int, default: Int) -> Decoder(Int) {
  field_with_default(number, varint_field, default)
}

/// Decoder for uint64 fields.
pub fn uint64(number: Int) -> Decoder(Int) {
  field(number, varint_field)
}

/// Decoder for uint64 fields with a default value.
pub fn uint64_with_default(number: Int, default: Int) -> Decoder(Int) {
  field_with_default(number, varint_field, default)
}

/// Decoder for string fields.
pub fn string(number: Int) -> Decoder(String) {
  field(number, string_field)
}

/// Decoder for string fields with a default value.
pub fn string_with_default(number: Int, default: String) -> Decoder(String) {
  field_with_default(number, string_field, default)
}

/// Decoder for boolean fields.
pub fn bool(number: Int) -> Decoder(Bool) {
  field(number, bool_field)
}

/// Decoder for boolean fields with a default value.
pub fn bool_with_default(number: Int, default: Bool) -> Decoder(Bool) {
  field_with_default(number, bool_field, default)
}

/// Decoder for bytes fields.
pub fn bytes(number: Int) -> Decoder(BitArray) {
  field(number, bytes_field)
}

/// Decoder for float fields.
pub fn float(number: Int) -> Decoder(Float) {
  field(number, float_field)
}

/// Decoder for double fields.
pub fn double(number: Int) -> Decoder(Float) {
  field(number, double_field)
}

/// Decoder for fixed32 fields (unsigned 32-bit integers).
pub fn fixed32(number: Int) -> Decoder(Int) {
  field(number, fixed32_int_field)
}

/// Decoder for fixed64 fields (unsigned 64-bit integers).
pub fn fixed64(number: Int) -> Decoder(Int) {
  field(number, fixed64_int_field)
}

/// Decoder for sfixed32 fields (signed 32-bit integers).
pub fn sfixed32(number: Int) -> Decoder(Int) {
  field(number, sfixed32_field)
}

/// Decoder for sfixed64 fields (signed 64-bit integers).
pub fn sfixed64(number: Int) -> Decoder(Int) {
  field(number, sfixed64_field)
}

/// Decoder for repeated int32 fields.
pub fn repeated_int32(number: Int) -> Decoder(List(Int)) {
  repeated_field(number, varint_field)
}

/// Decoder for repeated string fields.
pub fn repeated_string(number: Int) -> Decoder(List(String)) {
  repeated_field(number, string_field)
}

/// Decoder for nested message fields.
pub fn nested_message(number: Int, decoder: Decoder(a)) -> Decoder(a) {
  field(number, fn(f) { message_field(f, decoder) })
}

/// Decoder for optional nested message fields.
pub fn optional_nested_message(
  number: Int,
  decoder: Decoder(a),
) -> Decoder(Result(a, Nil)) {
  optional_field(number, fn(f) { message_field(f, decoder) })
}

// Builder pattern combinators - removed as they don't work well with Gleam's type system
// Use the subrecord pattern instead

// Alternative approach: use use syntax for building decoders
// This is more idiomatic Gleam and follows the pattern of gleam/dynamic/decode

/// Build a decoder using Gleam's use syntax.
/// This allows for composing multiple field decoders into a single decoder.
/// 
/// ## Examples
/// 
/// ```gleam
/// use name <- decode.subrecord(decode.string(1))
/// use age <- decode.subrecord(decode.int32(2))
/// decode.success(Person(name: name, age: age))
/// ```
pub fn subrecord(decoder: Decoder(a), next: fn(a) -> Decoder(b)) -> Decoder(b) {
  Decoder(fn(fields) {
    let Decoder(f) = decoder
    use value <- result.try(f(fields))
    let Decoder(g) = next(value)
    g(fields)
  })
}

/// Transform the result of a decoder using a mapping function.
/// 
/// ## Examples
/// 
/// ```gleam
/// decode.int32(1)
/// |> decode.map(fn(x) { x * 2 })
/// ```
pub fn map(decoder: Decoder(a), f: fn(a) -> b) -> Decoder(b) {
  Decoder(fn(fields) {
    let Decoder(g) = decoder
    use value <- result.try(g(fields))
    Ok(f(value))
  })
}

// Low-level message decoding

fn decode_message(data: BitArray) -> Result(List(Field), DecodeError) {
  decode_fields(data, [])
}

fn decode_fields(
  data: BitArray,
  acc: List(Field),
) -> Result(List(Field), DecodeError) {
  case data {
    <<>> -> Ok(list.reverse(acc))
    _ -> {
      use #(field, rest) <- result.try(decode_field(data))
      decode_fields(rest, [field, ..acc])
    }
  }
}

fn decode_field(data: BitArray) -> Result(#(Field, BitArray), DecodeError) {
  use #(tag, rest1) <- result.try(decode_varint_raw(data))
  let field_number = wire.get_field_number(tag)
  use wire_type <- result.try(
    wire.get_wire_type(tag)
    |> result.map_error(fn(_) { DecodeError("Invalid wire type") }),
  )

  case wire_type {
    wire.Varint -> {
      use #(value, rest2) <- result.try(decode_varint_raw(rest1))
      // Store varint as 64-bit integer in BitArray
      Ok(#(Field(field_number, wire_type, <<value:64>>), rest2))
    }
    wire.Fixed64 -> {
      use #(value, rest2) <- result.try(decode_fixed64_raw(rest1))
      Ok(#(Field(field_number, wire_type, value), rest2))
    }
    wire.LengthDelimited -> {
      use #(value, rest2) <- result.try(decode_length_delimited_raw(rest1))
      Ok(#(Field(field_number, wire_type, value), rest2))
    }
    wire.Fixed32 -> {
      use #(value, rest2) <- result.try(decode_fixed32_raw(rest1))
      Ok(#(Field(field_number, wire_type, value), rest2))
    }
    _ -> Error(DecodeError("Unsupported wire type"))
  }
}

fn decode_varint_raw(data: BitArray) -> Result(#(Int, BitArray), DecodeError) {
  decode_varint_helper(data, 0, 0)
}

fn decode_varint_helper(
  data: BitArray,
  value: Int,
  shift: Int,
) -> Result(#(Int, BitArray), DecodeError) {
  case data {
    <<>> -> Error(DecodeError("Unexpected end of data"))
    <<byte:int, rest:bits>> -> {
      let new_value =
        value
        |> int.bitwise_or(
          int.bitwise_and(byte, 0x7F)
          |> int.bitwise_shift_left(shift),
        )
      case int.bitwise_and(byte, 0x80) {
        0 -> Ok(#(new_value, rest))
        _ -> decode_varint_helper(rest, new_value, shift + 7)
      }
    }
    _ -> Error(DecodeError("Invalid varint data"))
  }
}

fn decode_fixed32_raw(
  data: BitArray,
) -> Result(#(BitArray, BitArray), DecodeError) {
  case data {
    <<value:32-bits, rest:bits>> -> Ok(#(value, rest))
    _ -> Error(DecodeError("Not enough data for fixed32"))
  }
}

fn decode_fixed64_raw(
  data: BitArray,
) -> Result(#(BitArray, BitArray), DecodeError) {
  case data {
    <<value:64-bits, rest:bits>> -> Ok(#(value, rest))
    _ -> Error(DecodeError("Not enough data for fixed64"))
  }
}

fn decode_length_delimited_raw(
  data: BitArray,
) -> Result(#(BitArray, BitArray), DecodeError) {
  use #(length, rest) <- result.try(decode_varint_raw(data))
  case bit_array.byte_size(rest) >= length {
    True -> {
      let bytes_to_take = length * 8
      case rest {
        <<value:size(bytes_to_take)-bits, rest:bits>> -> Ok(#(value, rest))
        _ -> Error(DecodeError("Not enough data for length-delimited field"))
      }
    }
    False -> Error(DecodeError("Not enough data for length-delimited field"))
  }
}

/// Decodes a zigzag-encoded integer back to its signed value.
/// Zigzag encoding is used for sint32 and sint64 fields to efficiently
/// encode negative numbers.
/// 
/// ## Examples
/// 
/// ```gleam
/// decode_zigzag(0) // Returns 0
/// decode_zigzag(1) // Returns -1
/// decode_zigzag(2) // Returns 1
/// ```
pub fn decode_zigzag(value: Int) -> Int {
  case int.bitwise_and(value, 1) {
    0 -> int.bitwise_shift_right(value, 1)
    _ -> -int.bitwise_shift_right(value + 1, 1)
  }
}

/// Decoder for sint32 fields (signed 32-bit integers with zigzag encoding).
/// 
/// ## Examples
/// 
/// ```gleam
/// sint32(1) // Decodes field 1 as a zigzag-encoded int32
/// ```
pub fn sint32(number: Int) -> Decoder(Int) {
  Decoder(fn(fields) {
    let Decoder(f) =
      field(number, fn(f) {
        use value <- result.try(varint_field(f))
        Ok(decode_zigzag(value))
      })
    f(fields)
  })
}

/// Decoder for sint64 fields (signed 64-bit integers with zigzag encoding).
/// 
/// ## Examples
/// 
/// ```gleam
/// sint64(1) // Decodes field 1 as a zigzag-encoded int64
/// ```
pub fn sint64(number: Int) -> Decoder(Int) {
  Decoder(fn(fields) {
    let Decoder(f) =
      field(number, fn(f) {
        use value <- result.try(varint_field(f))
        Ok(decode_zigzag(value))
      })
    f(fields)
  })
}
