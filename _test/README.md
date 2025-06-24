# Zscaler Script Tests

This directory contains BATS (Bash Automated Testing System) tests for the `zscaler-mac.sh` script.

## Prerequisites

Install BATS:

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get install bats

# Or from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

## Running Tests

```bash
# Run all tests
./_test/run_tests.sh

# Or run directly with bats
cd _test
bats zscaler-mac.bats

# Run specific test
bats zscaler-mac.bats --filter "script shows help"

# Verbose output for debugging
bats zscaler-mac.bats --verbose-run

# TAP format output
bats zscaler-mac.bats --tap
```

## Convenience Commands

```bash
# Run tests continuously on file changes (requires entr or nodemon)
find . -name "*.sh" -o -name "*.bats" -o -name "*.bash" | entr -c ./_test/run_tests.sh

# Lint shell scripts (requires shellcheck)
shellcheck zscaler-mac.sh _test/*.bats _test/helpers/*.bash

# Format shell scripts (requires shfmt)
shfmt -w zscaler-mac.sh _test/*.bats _test/helpers/*.bash

# Test script modes
./zscaler-mac.sh --dry-run          # Dry run mode
./zscaler-mac.sh --help             # Show help
./zscaler-mac.sh --dry-run --azure-cli --profile  # Test all features
```

## Test Structure

- `zscaler-mac.bats` - Main test file containing all test cases
- `helpers/mocks.bash` - Mock command utilities and helper functions
- Tests certificate handling, Azure CLI integration, and shell profile updates

## Mock System

The test suite uses a mocking system to simulate external commands:

### Basic Mocking

```bash
# Create a simple mock
mock_command "tool_name" exit_code "optional_output"

# Create a mock with custom behavior
mock_command_with_script "tool_name" 'custom bash script'
```

### Assertions

```bash
# Check if mock was called
assert_mock_called "command" "expected arguments"

# Check if mock was NOT called
assert_mock_not_called "command"

# Get call count
count=$(get_mock_call_count "command")
```

### Common Mocks Used

- `mock_command "az"` - Simulates Azure CLI

## Test Coverage

The test suite covers:

1. **Basic Functionality**
   - Help display (`--help`, `-h`)
   - Certificate validation
   - Dry run mode

2. **Azure CLI Integration**
   - Certificate bundle creation
   - Missing Azure CLI handling
   - Dry run behavior

3. **Shell Profile Updates**
   - Environment variable configuration
   - Shell detection (zsh/bash)
   - Idempotency

4. **Error Handling**
   - Invalid options
   - Missing certificates
   - Missing directories

## Adding New Tests

1. Create or update mocks in `helpers/mocks.bash` if needed
2. Add test cases to `zscaler-mac.bats`:

```bash
@test "description of what you're testing" {
  # Setup mocks
  mock_command "some_tool"

  # Run function
  run ./zscaler-mac.sh --some-option

  # Assert results
  [ "$status" -eq 0 ]
  [[ "$output" =~ "expected output" ]]
  assert_mock_called "some_tool" "expected args"
}
```

## Debugging Tests

Run with verbose output:

```bash
bats zscaler-mac.bats --verbose-run
```

Use `echo` statements in tests (output only shown on failure):

```bash
@test "debugging example" {
  echo "Debug info: $variable" >&3
  # ... rest of test
}
```
