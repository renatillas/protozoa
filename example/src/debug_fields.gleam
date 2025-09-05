import generated/proto
import gleam/bit_array
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import protozoa/decode
import protozoa/wire

pub fn main() {
  io.println("🔍 Debugging field parsing")

  let user =
    proto.User(
      id: 42,
      name: "Test",
      email: "test@example.com",
      created_at: proto.Timestamp(seconds: 1_640_995_200, nanos: 0),
      is_active: True,
      role: proto.ADMIN,
      tags: [],
      bio: proto.StringValue(value: "Bio"),
    )

  let encoded = proto.encode_user(user)

  io.println("Attempting to manually parse all fields...")

  case decode_all_fields(encoded) {
    Ok(fields) -> {
      io.println(
        "Successfully parsed "
        <> int.to_string(list.length(fields))
        <> " fields",
      )

      list.each(fields, fn(field) {
        io.println(
          "  Field "
          <> int.to_string(field.number)
          <> ": wire_type="
          <> string.inspect(field.wire_type),
        )
      })

      // Build field dict and check what's in it
      let field_dict = build_field_dict(fields)
      io.println("\nField dictionary contents:")
      dict.to_list(field_dict)
      |> list.each(fn(entry) {
        let #(field_num, field_list) = entry
        io.println(
          "  Field "
          <> int.to_string(field_num)
          <> " has "
          <> int.to_string(list.length(field_list))
          <> " entries",
        )
      })

      // Try to extract field 6 specifically
      case dict.get(field_dict, 6) {
        Ok(field_list) ->
          io.println(
            "✅ Field 6 found with "
            <> int.to_string(list.length(field_list))
            <> " entries",
          )
        Error(_) -> io.println("❌ Field 6 not found in dictionary")
      }
    }
    Error(err) -> io.println("❌ Field parsing failed: " <> string.inspect(err))
  }
}

fn decode_all_fields(data: BitArray) -> Result(List(decode.Field), String) {
  decode_fields_helper(data, [])
}

fn decode_fields_helper(
  data: BitArray,
  acc: List(decode.Field),
) -> Result(List(decode.Field), String) {
  case data {
    <<>> -> Ok(list.reverse(acc))
    _ -> {
      case decode_single_field(data) {
        Ok(#(field, rest)) -> {
          io.println("Parsed field " <> int.to_string(field.number))
          decode_fields_helper(rest, [field, ..acc])
        }
        Error(err) -> Error(err)
      }
    }
  }
}

fn decode_single_field(
  data: BitArray,
) -> Result(#(decode.Field, BitArray), String) {
  case decode_varint(data) {
    Ok(#(tag, rest1)) -> {
      let field_number = get_field_number(tag)
      case get_wire_type(tag) {
        Ok(wire_type) -> {
          case parse_field_data(wire_type, rest1) {
            Ok(#(field_data, rest2)) -> {
              Ok(#(decode.Field(field_number, wire_type, field_data), rest2))
            }
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error("Wire type error: " <> err)
      }
    }
    Error(err) -> Error("Varint error: " <> err)
  }
}

fn parse_field_data(
  wire_type: wire.WireType,
  data: BitArray,
) -> Result(#(BitArray, BitArray), String) {
  case wire_type {
    wire.Varint -> {
      case decode_varint(data) {
        Ok(#(value, rest)) -> Ok(#(<<value:64>>, rest))
        Error(err) -> Error(err)
      }
    }
    wire.LengthDelimited -> {
      case decode_varint(data) {
        Ok(#(length, rest)) -> {
          case bit_array.byte_size(rest) >= length {
            True -> {
              let bytes_to_take = length * 8
              case rest {
                <<value:size(bytes_to_take)-bits, remaining:bits>> ->
                  Ok(#(value, remaining))
                _ -> Error("Insufficient data for length-delimited field")
              }
            }
            False -> Error("Insufficient data for length-delimited field")
          }
        }
        Error(err) -> Error(err)
      }
    }
    wire.Fixed32 -> {
      case data {
        <<value:32-bits, rest:bits>> -> Ok(#(value, rest))
        _ -> Error("Insufficient data for fixed32")
      }
    }
    wire.Fixed64 -> {
      case data {
        <<value:64-bits, rest:bits>> -> Ok(#(value, rest))
        _ -> Error("Insufficient data for fixed64")
      }
    }
    _ -> Error("Unsupported wire type")
  }
}

// Helper functions copied from wire module
fn get_field_number(tag: Int) -> Int {
  int.bitwise_shift_right(tag, 3)
}

fn get_wire_type(tag: Int) -> Result(wire.WireType, String) {
  let wire_type_value = int.bitwise_and(tag, 7)
  case wire_type_value {
    0 -> Ok(wire.Varint)
    1 -> Ok(wire.Fixed64)
    2 -> Ok(wire.LengthDelimited)
    3 -> Ok(wire.StartGroup)
    4 -> Ok(wire.EndGroup)
    5 -> Ok(wire.Fixed32)
    _ -> Error("Invalid wire type: " <> int.to_string(wire_type_value))
  }
}

fn decode_varint(data: BitArray) -> Result(#(Int, BitArray), String) {
  decode_varint_helper(data, 0, 0)
}

fn decode_varint_helper(
  data: BitArray,
  value: Int,
  shift: Int,
) -> Result(#(Int, BitArray), String) {
  case data {
    <<>> -> Error("Unexpected end of data")
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
    _ -> Error("Invalid varint data")
  }
}

fn build_field_dict(
  fields: List(decode.Field),
) -> dict.Dict(Int, List(decode.Field)) {
  list.fold(fields, dict.new(), fn(acc, field) {
    dict.upsert(acc, field.number, fn(existing) {
      case existing {
        Some(field_list) -> list.append(field_list, [field])
        None -> [field]
      }
    })
  })
}
