# gloto

A Protocol Buffers library for Gleam, providing encoding and decoding of protobuf messages.

[![Package Version](https://img.shields.io/hexpm/v/gloto)](https://hex.pm/packages/gloto)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gloto/)

## Installation

```sh
gleam add gloto@1
```

## Usage

### Encoding Messages

```gleam
import gloto
import gleam/int
import gleam/io

pub fn encode_example() {
  // Create a protobuf message with multiple fields
  let message = gloto.build_message([
    gloto.encode_int32(1, 42),           // Field 1: int32
    gloto.encode_string(2, "Hello"),     // Field 2: string
    gloto.encode_bool(3, True),          // Field 3: bool
  ])
  
  // message is now a BitArray containing the encoded protobuf
  message
}
```

### Decoding Messages

```gleam
import gloto
import gleam/int
import gleam/io

pub fn decode_example(data: BitArray) {
  case gloto.decode(data) {
    Ok(fields) -> {
      // Find specific fields by number
      case gloto.find_field(fields, 1) {
        Ok(field) -> {
          case gloto.decode_varint_value(field) {
            Ok(value) -> io.println("Field 1: " <> int.to_string(value))
            Error(_) -> io.println("Failed to decode field 1")
          }
        }
        Error(_) -> io.println("Field 1 not found")
      }
    }
    Error(_) -> io.println("Failed to decode message")
  }
}
```

### Nested Messages

```gleam
import gloto

pub fn nested_message_example() {
  // Create an inner message
  let inner = gloto.build_message([
    gloto.encode_string(1, "inner value"),
    gloto.encode_int32(2, 100),
  ])
  
  // Embed it in an outer message
  let outer = gloto.build_message([
    gloto.encode_int32(1, 999),
    gloto.encode_message_field(2, inner),  // Nested message in field 2
  ])
  
  outer
}
```

### Repeated Fields

Protocol Buffers supports repeated fields. Simply encode multiple values with the same field number:

```gleam
import gloto

pub fn repeated_fields_example() {
  let message = gloto.build_message([
    gloto.encode_int32(1, 10),
    gloto.encode_int32(1, 20),  // Same field number
    gloto.encode_int32(1, 30),  // Creates a repeated field
    gloto.encode_string(2, "other field"),
  ])
  
  // When decoding, use find_all_fields to get all values
  case gloto.decode(message) {
    Ok(fields) -> {
      let repeated = gloto.find_all_fields(fields, 1)
      // repeated will contain all three int32 values
      repeated
    }
    Error(_) -> panic
  }
}
```

## Supported Types

- **Varint**: int32, int64, bool
- **Fixed32**: 32-bit values with fixed size
- **Fixed64**: 64-bit values with fixed size
- **Length-delimited**: strings, bytes, nested messages

## Architecture

The library is structured into three main modules:

- `gloto/wire` - Wire format types and tag encoding/decoding
- `gloto/encoder` - Functions for encoding various protobuf types
- `gloto/decoder` - Functions for decoding protobuf messages
- `gloto` - High-level API for working with protobuf messages

## Future Plans

- Code generation from .proto files
- gRPC support
- Schema validation
- More comprehensive type support

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

Further documentation can be found at <https://hexdocs.pm/gloto>.
