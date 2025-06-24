#!/usr/bin/env bash
# Test helper functions for mocking commands

# Directory to store mock commands
export MOCK_BIN_DIR="$BATS_TEST_TMPDIR/mock_bin"

# Setup mock environment
setup_mocks() {
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"
  
  # Create a directory for recording mock calls
  export MOCK_CALLS_DIR="$BATS_TEST_TMPDIR/mock_calls"
  mkdir -p "$MOCK_CALLS_DIR"
}

# Create a mock command that records its calls
mock_command() {
  local cmd="$1"
  local exit_code="${2:-0}"
  local output="${3:-}"
  
  cat > "$MOCK_BIN_DIR/$cmd" << EOF
#!/usr/bin/env bash
# Record the call
echo "\$@" >> "$MOCK_CALLS_DIR/$cmd.calls"

# Output if provided
if [[ -n "$output" ]]; then
  echo "$output"
fi

exit $exit_code
EOF
  chmod +x "$MOCK_BIN_DIR/$cmd"
}

# Check if a mock command was called
assert_mock_called() {
  local cmd="$1"
  local expected_args="${2:-}"
  
  if [[ ! -f "$MOCK_CALLS_DIR/$cmd.calls" ]]; then
    echo "Mock command '$cmd' was not called" >&2
    return 1
  fi
  
  if [[ -n "$expected_args" ]]; then
    if ! grep -qF -- "$expected_args" "$MOCK_CALLS_DIR/$cmd.calls"; then
      echo "Mock command '$cmd' was not called with expected args: $expected_args" >&2
      echo "Actual calls:" >&2
      cat "$MOCK_CALLS_DIR/$cmd.calls" >&2
      return 1
    fi
  fi
  
  return 0
}

# Check if a mock command was NOT called
assert_mock_not_called() {
  local cmd="$1"
  
  if [[ -f "$MOCK_CALLS_DIR/$cmd.calls" ]]; then
    echo "Mock command '$cmd' was called but should not have been" >&2
    echo "Calls:" >&2
    cat "$MOCK_CALLS_DIR/$cmd.calls" >&2
    return 1
  fi
  
  return 0
}

# Cleanup function
teardown_mocks() {
  # Remove mock binaries from PATH
  export PATH="${PATH#"$MOCK_BIN_DIR":}"
  
  # Clean up temporary directories
  rm -rf "$MOCK_BIN_DIR" "$MOCK_CALLS_DIR"
}