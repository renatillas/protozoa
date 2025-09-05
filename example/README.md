# Protozoa Example Project

This example project demonstrates the usage of the Protozoa Protocol Buffer library for Gleam.

## Overview

Protozoa is a Protocol Buffer compiler and runtime library for Gleam that supports all 27 Google Protocol Buffer well-known types and provides complete encode/decode functionality.

## What's Demonstrated

This example showcases:

### ✅ Core Protocol Buffer Features
- **Basic Types**: `int32`, `string`, `bool`, `bytes`, `repeated` fields
- **Enums**: User roles with proper encoding/decoding
- **Oneof Fields**: Union types with multiple data variants
- **Well-Known Types**: `Timestamp`, `StringValue`, and other Google well-known types

### ✅ Advanced Features
- **Message Nesting**: Complex message structures
- **Type Safety**: Full Gleam type safety with generated types
- **Encoding/Decoding**: Bidirectional serialization with proper error handling

## Files Structure

```
example/
├── src/
│   ├── proto/
│   │   └── simple.proto          # Protocol Buffer definitions
│   ├── generated/
│   │   └── proto.gleam          # Auto-generated Gleam code
│   └── simple_example.gleam     # Main example application
├── test/
│   └── simple_test.gleam        # Test suite
└── README.md                    # This file
```

## Protocol Buffer Definitions

### User Message
Demonstrates basic types, enums, repeated fields, and well-known types:

```proto
message User {
  int32 id = 1;
  string name = 2;
  string email = 3;
  google.protobuf.Timestamp created_at = 4;
  bool is_active = 5;
  UserRole role = 6;
  repeated string tags = 7;
  google.protobuf.StringValue bio = 8;
}
```

### SimpleMessage with Oneof
Demonstrates union types (oneof fields):

```proto
message SimpleMessage {
  string id = 1;
  
  oneof data {
    string text_data = 2;
    int64 numeric_data = 3;
    bytes binary_data = 4;
  }
  
  string description = 5;
  bool enabled = 6;
}
```

## Running the Example

### Prerequisites
- Gleam >= 1.5.0
- Protozoa library

### Generate Code
```bash
# Generate Gleam code from proto files
gleam run -m protozoa src/proto/simple.proto src/generated/
```

### Run the Example
```bash
gleam run -m simple_example
```

Expected output:
```
🚀 Protozoa Simple Example
=========================
👤 Created user: Alice (alice@example.com)
📦 Encoded user data successfully
💬 Created simple message: msg_001
✅ Successfully decoded message: msg_001
   Text data: Hello, World!
✅ Simple example completed!
```

### Run Tests
```bash
gleam run -m gleeunit -- --module simple_test
```

All tests should pass:
```
3 tests, no failures
```

## Generated Code Features

The generated `proto.gleam` file includes:

### Type Definitions
- **Union Types**: For oneof fields with proper Gleam algebraic data types
- **Record Types**: For messages with named fields
- **Enum Types**: For protocol buffer enums

### Encoding Functions
- `encode_user(user: User) -> BitArray`
- `encode_simplemessage(message: SimpleMessage) -> BitArray`
- `encode_timestamp(timestamp: Timestamp) -> BitArray`

### Decoding Functions
- `decode_user(data: BitArray) -> Result(User, List(DecodeError))`
- `decode_simplemessage(data: BitArray) -> Result(SimpleMessage, List(DecodeError))`
- `decode_timestamp(data: BitArray) -> Result(Timestamp, List(DecodeError))`

### Well-Known Types Support
The generated code includes full support for Google's Protocol Buffer well-known types:
- `Timestamp` - for date/time values
- `StringValue` - for optional strings
- `Int32Value`, `Int64Value` - for optional integers
- And many more...

## Key Features Demonstrated

### 1. Type Safety
```gleam
// Compile-time type checking
let user = proto.User(
  id: 42,
  name: "Alice",
  // ... other fields
)
```

### 2. Oneof Fields (Union Types)
```gleam
// Pattern matching on union types
case message.data {
  option.Some(proto.TextData(text)) -> // Handle text
  option.Some(proto.NumericData(num)) -> // Handle number
  option.Some(proto.BinaryData(bytes)) -> // Handle binary
  option.None -> // Handle no data
}
```

### 3. Error Handling
```gleam
// Safe decoding with proper error handling
case proto.decode_user(encoded_data) {
  Ok(user) -> // Successfully decoded
  Error(decode_errors) -> // Handle decode errors
}
```

### 4. Well-Known Types
```gleam
// Using Google's well-known types
let timestamp = proto.Timestamp(
  seconds: 1640995200,
  nanos: 123456789,
)
```

## What's Working

✅ **Basic Types**: All primitive types work correctly  
✅ **Enums**: User roles and other enums  
✅ **Oneof Fields**: Union types with proper type safety  
✅ **Well-Known Types**: Timestamp and other Google types  
✅ **Encoding/Decoding**: Round-trip serialization  
✅ **Type Safety**: Full Gleam compiler integration  

## Performance Notes

- **Efficient Encoding**: Uses Protocol Buffer's compact binary format
- **Memory Safe**: Leverages Gleam's memory safety guarantees
- **Type Safe**: No runtime type errors with proper Gleam types

## Integration

To use Protozoa in your own project:

1. **Add Dependency**: Add protozoa to your `gleam.toml`
2. **Define Schemas**: Create `.proto` files
3. **Generate Code**: Run `gleam run -m protozoa your.proto src/generated/`
4. **Import & Use**: Import generated modules and use the types

This example demonstrates that Protozoa successfully provides a complete, type-safe Protocol Buffer implementation for Gleam with excellent integration into the Gleam ecosystem.