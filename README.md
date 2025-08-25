# Protozoa

A Protocol Buffers library for Gleam, providing encoding and decoding of protobuf messages.

[![Package Version](https://img.shields.io/hexpm/v/protozoa)](https://hex.pm/packages/protozoa)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/protozoa/)

## Roadmap / Missing Features

### High Priority
These features are essential for production use and compatibility with existing protobuf ecosystems:

- [ ] **Import system** - Support for importing other .proto files
  - [ ] Basic import statements
  - [ ] Import path resolution
  - [ ] Public imports
  - [ ] Dependency management
- [ ] **Well-known types** - Google's standard protobuf types
  - [ ] `google.protobuf.Timestamp`
  - [ ] `google.protobuf.Duration`
  - [ ] `google.protobuf.Any`
  - [ ] `google.protobuf.Struct` / `Value`
  - [ ] `google.protobuf.Empty`
  - [ ] Wrapper types (`StringValue`, `Int32Value`, etc.)
- [ ] **Complete code generation** - Fix existing TODOs in codegen
  - [ ] All repeated field type encoders
  - [ ] All map key/value type combinations
  - [ ] All oneof field type variants
- [ ] **Field options** - Support field-level configuration
  - [ ] `deprecated` option
  - [ ] `json_name` option
  - [ ] `packed` option declaration (encoding already works)
  - [ ] Custom field options

### Medium Priority
Important for feature completeness and broader compatibility:

- [ ] **Services/RPC** - Support for service definitions
  - [ ] Service definition parsing
  - [ ] Method definitions
  - [ ] Code generation for service stubs
  - [ ] Streaming support (client/server/bidirectional)
- [ ] **Proto2 support** - Full proto2 compatibility
  - [ ] Required/optional field semantics
  - [ ] Default values
  - [ ] Extensions and extension ranges
  - [ ] Groups (deprecated but still used)
- [ ] **Unknown field handling** - Preserve unknown fields during decode/encode
- [ ] **File options** - Support file-level options
  - [ ] `java_package`, `java_outer_classname`
  - [ ] `optimize_for` (SPEED/CODE_SIZE/LITE_RUNTIME)
  - [ ] `go_package`
  - [ ] Custom file options
- [ ] **Recursive messages** - Full support for self-referential message types
- [ ] **JSON support** - JSON encoding/decoding as per proto3 JSON mapping

### Low Priority
Nice-to-have features and optimizations:

- [ ] **Advanced parsing**
  - [ ] Comment preservation in AST
  - [ ] Source location tracking
  - [ ] Better error messages with line numbers
- [ ] **Performance optimizations**
  - [ ] Lazy decoding for large messages
  - [ ] Streaming decode/encode for large data
  - [ ] Memory pooling for repeated allocations
  - [ ] Zero-copy decoding where possible
- [ ] **Validation**
  - [ ] Message validation against schema
  - [ ] Field constraint validation
  - [ ] Required field checking (proto2)
- [ ] **Tooling**
  - [ ] Proto file formatter
  - [ ] Proto file linter
  - [ ] Schema evolution checker
  - [ ] Documentation generator from proto comments
- [ ] **Extended type support**
  - [ ] Support for custom options
  - [ ] Experimental/beta proto3 features
  - [ ] Proto3 optional presence tracking

## Current Limitations

- Only supports proto3 syntax (proto2 partially works but not guaranteed)
- All message definitions must be in a single .proto file (no imports)
- No service/RPC definitions
- No support for proto2 extensions
- Some repeated field and map type combinations not yet implemented
