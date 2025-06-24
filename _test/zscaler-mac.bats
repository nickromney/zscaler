#!/usr/bin/env bats

load helpers/mocks

# Setup and teardown
setup() {
  setup_mocks
  
  # Set up test environment
  export HOME="$BATS_TEST_TMPDIR"
  export ZSCALER_DIR="$HOME/.zscalerCerts"
  
  # Create mock certificate directory with certificates
  mkdir -p "$ZSCALER_DIR"
  echo "-----BEGIN CERTIFICATE-----" > "$ZSCALER_DIR/ZscalerRootCertificate.crt"
  echo "Mock Zscaler Root Certificate" >> "$ZSCALER_DIR/ZscalerRootCertificate.crt"
  echo "-----END CERTIFICATE-----" >> "$ZSCALER_DIR/ZscalerRootCertificate.crt"
  
  echo "-----BEGIN CERTIFICATE-----" > "$ZSCALER_DIR/zscalerCAbundle.pem"
  echo "Mock Zscaler CA Bundle" >> "$ZSCALER_DIR/zscalerCAbundle.pem"
  echo "-----END CERTIFICATE-----" >> "$ZSCALER_DIR/zscalerCAbundle.pem"
  
  # Create mock shell profiles
  touch "$HOME/.zshrc"
  touch "$HOME/.bash_profile"
  touch "$HOME/.bashrc"
  
  # Change to the script directory
  cd "$BATS_TEST_DIRNAME/.." || exit 1
  
  # Source the script functions only (not main)
  # shellcheck disable=SC1091
  source ./zscaler-mac.sh --source
}

teardown() {
  teardown_mocks
}

# Tests for basic functionality
@test "script shows help with --help" {
  run ./zscaler-mac.sh --help
  [ "$status" -eq 1 ]  # Help exits with status 1
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "--azure-cli" ]]
  [[ "$output" =~ "--profile" ]]
  [[ "$output" =~ "--dry-run" ]]
}

@test "script shows help with -h" {
  run ./zscaler-mac.sh -h
  [ "$status" -eq 1 ]  # Help exits with status 1
  [[ "$output" =~ "Usage:" ]]
}

# Tests for certificate validation
@test "script warns in dry-run when certificate directory doesn't exist" {
  rm -rf "$ZSCALER_DIR"
  run ./zscaler-mac.sh --dry-run --profile
  [ "$status" -eq 0 ]  # Should succeed in dry-run mode
  [[ "$output" =~ \[DRY\ RUN\]\ Warning:\ Zscaler\ directory\ not\ found ]]
}

@test "script warns in dry-run when certificates are missing" {
  rm -f "$ZSCALER_DIR/ZscalerRootCertificate.crt"
  run ./zscaler-mac.sh --dry-run --profile
  [ "$status" -eq 0 ]  # Should succeed in dry-run mode
  [[ "$output" =~ \[DRY\ RUN\]\ Warning:\ Zscaler\ certificate\ not\ found ]]
}

@test "script fails when certificate directory doesn't exist (not dry-run)" {
  rm -rf "$ZSCALER_DIR"
  run ./zscaler-mac.sh --profile
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: Zscaler directory not found" ]]
}

@test "script fails when certificates are missing (not dry-run)" {
  rm -f "$ZSCALER_DIR/ZscalerRootCertificate.crt"
  run ./zscaler-mac.sh --profile
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: Zscaler certificate not found" ]]
}

# Tests for dry run mode
@test "dry run mode doesn't make changes" {
  # Create a mock az command
  mock_command "az" 0
  
  run ./zscaler-mac.sh --dry-run --azure-cli --profile
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY\ RUN\] ]]
  
  # Check that no actual changes were made
  [ ! -f "$HOME/.zscalerCerts/azure-cacert.pem" ]
  
  # Check that profile wasn't modified
  [ ! -s "$HOME/.zshrc" ]
}

# Tests for Azure CLI certificate bundle
@test "azure-cli creates certificate bundle in dry run" {
  # Create mock Azure CLI installation
  mkdir -p "$HOME/homebrew/Cellar/azure-cli/2.50.0/libexec/lib/python3.11/site-packages/certifi"
  echo "-----BEGIN CERTIFICATE-----" > "$HOME/homebrew/Cellar/azure-cli/2.50.0/libexec/lib/python3.11/site-packages/certifi/cacert.pem"
  echo "Mock CA Bundle" >> "$HOME/homebrew/Cellar/azure-cli/2.50.0/libexec/lib/python3.11/site-packages/certifi/cacert.pem" 
  echo "-----END CERTIFICATE-----" >> "$HOME/homebrew/Cellar/azure-cli/2.50.0/libexec/lib/python3.11/site-packages/certifi/cacert.pem"
  
  # Mock the find command to return our test path
  export HOMEBREW_PATHS=("$HOME/homebrew/Cellar/azure-cli")
  
  run ./zscaler-mac.sh --dry-run --azure-cli
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Would execute" ]] || [[ "$output" =~ "certificate bundle created" ]]
}

@test "azure-cli works with real or mocked installation" {
  # This test will pass whether Azure CLI is installed or not
  run ./zscaler-mac.sh --dry-run --azure-cli
  
  # If Azure CLI is found, it should succeed
  if [[ "$output" =~ "Found Azure CLI Python" ]]; then
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would execute" ]] || [[ "$output" =~ "certificate bundle created" ]]
  else
    # If not found, it should fail with appropriate message
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Could not find Azure CLI Python installation" ]]
  fi
}

# Tests for profile updates
@test "profile update adds environment variables in dry run" {
  run ./zscaler-mac.sh --dry-run --profile
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Added environment variable SSL_CERT_FILE" ]]
  [[ "$output" =~ "Added environment variable CURL_CA_BUNDLE" ]]
  [[ "$output" =~ "Added environment variable NODE_EXTRA_CA_CERTS" ]]
}

@test "profile update detects zsh shell" {
  # shellcheck disable=SC2030
  export SHELL="/bin/zsh"
  run ./zscaler-mac.sh --dry-run --profile
  [ "$status" -eq 0 ]
  [[ "$output" =~ \.zshrc ]]
}

@test "profile update detects bash shell" {
  # shellcheck disable=SC2031
  export SHELL="/bin/bash"
  # Shell profile already created in setup as $HOME/.bash_profile
  
  run ./zscaler-mac.sh --dry-run --profile
  [ "$status" -eq 0 ]
  [[ "$output" =~ \.bash_profile ]]
}

# Integration tests
@test "script completes successfully with profile option in dry run" {
  run ./zscaler-mac.sh --dry-run --profile
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Added environment variable" ]] || [[ "$output" =~ "Would execute" ]]
}

@test "script handles no action options" {
  run ./zscaler-mac.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
}

# Tests for error handling
@test "script handles invalid options" {
  run ./zscaler-mac.sh --invalid-option
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown option" ]]
}


