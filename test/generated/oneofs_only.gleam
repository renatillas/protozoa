import gleam/dict
import gleam/option
import protozoa/decode
import protozoa/encode

pub type SimpleOneof {
  SimpleOneof(common_field: String, value: option.Option(SimpleOneofValue))
}

pub type SimpleOneofValue {
  StringValue(String)
  IntValue(Int)
  BoolValue(Bool)
}

pub type SubMessage {
  SubMessage(content: String)
}

pub fn encode_simpleoneof(simpleoneof: SimpleOneof) -> BitArray {
  encode.message([
    encode.string_field(4, simpleoneof.common_field),
    case simpleoneof.value {
      option.Some(oneof_value) -> {
        case oneof_value {
          StringValue(value) -> encode.string_field(1, value)
          IntValue(value) -> encode.int32_field(2, value)
          BoolValue(value) -> encode.bool_field(3, value)
        }
      }
      option.None -> <<>>
    },
  ])
}

pub fn encode_submessage(submessage: SubMessage) -> BitArray {
  encode.message([encode.string_field(1, submessage.content)])
}

pub fn simpleoneof_decoder() -> decode.Decoder(SimpleOneof) {
  use common_field <- decode.then(decode.string_with_default(4, ""))
  use value <- decode.then(oneof_value_decoder())
  decode.success(SimpleOneof(common_field: common_field, value: value))
}

pub fn decode_simpleoneof(
  data: BitArray,
) -> Result(SimpleOneof, List(decode.DecodeError)) {
  decode.run(data, simpleoneof_decoder())
}

fn oneof_value_decoder() -> decode.Decoder(option.Option(SimpleOneofValue)) {
  decode.from_field_dict(fn(fields) {
    case dict.get(fields, 1) {
      Ok([field, ..]) -> {
        case decode.string_field(field) {
          Ok(value) -> Ok(option.Some(StringValue(value)))
          Error(_) -> {
            case dict.get(fields, 2) {
              Ok([field, ..]) -> {
                case decode.int32_field(field) {
                  Ok(value) -> Ok(option.Some(IntValue(value)))
                  Error(_) -> {
                    case dict.get(fields, 3) {
                      Ok([field, ..]) -> {
                        case decode.bool_field(field) {
                          Ok(value) -> Ok(option.Some(BoolValue(value)))
                          Error(_) -> Ok(option.None)
                        }
                      }
                      Ok([]) -> Ok(option.None)
                      Error(_) -> Ok(option.None)
                    }
                  }
                }
              }
              _ -> {
                case dict.get(fields, 3) {
                  Ok([field, ..]) -> {
                    case decode.bool_field(field) {
                      Ok(value) -> Ok(option.Some(BoolValue(value)))
                      Error(_) -> Ok(option.None)
                    }
                  }
                  Ok([]) -> Ok(option.None)
                  Error(_) -> Ok(option.None)
                }
              }
            }
          }
        }
      }
      _ -> {
        case dict.get(fields, 2) {
          Ok([field, ..]) -> {
            case decode.int32_field(field) {
              Ok(value) -> Ok(option.Some(IntValue(value)))
              Error(_) -> {
                case dict.get(fields, 3) {
                  Ok([field, ..]) -> {
                    case decode.bool_field(field) {
                      Ok(value) -> Ok(option.Some(BoolValue(value)))
                      Error(_) -> Ok(option.None)
                    }
                  }
                  Ok([]) -> Ok(option.None)
                  Error(_) -> Ok(option.None)
                }
              }
            }
          }
          _ -> {
            case dict.get(fields, 3) {
              Ok([field, ..]) -> {
                case decode.bool_field(field) {
                  Ok(value) -> Ok(option.Some(BoolValue(value)))
                  Error(_) -> Ok(option.None)
                }
              }
              Ok([]) -> Ok(option.None)
              Error(_) -> Ok(option.None)
            }
          }
        }
      }
    }
  })
}

pub fn submessage_decoder() -> decode.Decoder(SubMessage) {
  use content <- decode.then(decode.string_with_default(1, ""))
  decode.success(SubMessage(content: content))
}

pub fn decode_submessage(
  data: BitArray,
) -> Result(SubMessage, List(decode.DecodeError)) {
  decode.run(data, submessage_decoder())
}
