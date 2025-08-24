.PHONY: test clean build all setup-test

# Default target
all: build

# Build the project
build:
	gleam build

# Setup test environment by generating test proto files
setup-test:
	@echo "Setting up test environment..."
	@./scripts/setup_tests.sh

# Run tests with proper setup and cleanup
test: setup-test
	@echo "Running tests..."
	gleam test
	@echo "Cleaning up test files..."
	@rm -rf build/test_gen

# Clean all build artifacts and generated test files
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf _build/
	@echo "Clean complete"

# Generate a proto file (usage: make generate INPUT=file.proto OUTPUT=file_pb.gleam)
generate:
	@if [ -z "$(INPUT)" ] || [ -z "$(OUTPUT)" ]; then \
		echo "Usage: make generate INPUT=file.proto OUTPUT=file_pb.gleam"; \
		exit 1; \
	fi
	gleam run -m gloto -- generate $(INPUT) $(OUTPUT)

# Check code formatting and linting
check:
	gleam check
	gleam format --check src test

# Format code
format:
	gleam format src test

# Show help
help:
	@echo "Available targets:"
	@echo "  all        - Build the project (default)"
	@echo "  build      - Build the project"
	@echo "  test       - Run tests with automatic setup/cleanup"
	@echo "  clean      - Remove all build artifacts"
	@echo "  generate   - Generate Gleam code from proto file"
	@echo "  check      - Run code checks and formatting verification"
	@echo "  format     - Format the code"
	@echo "  help       - Show this help message"