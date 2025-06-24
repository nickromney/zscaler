#!/bin/bash

# Constants and flags
DRY_RUN=0
INSTALL_AZURE=0
UPDATE_PROFILE=0

# Zscaler paths
ZSCALER_DIR="$HOME/.zscalerCerts"
ZSCALER_CERT="$ZSCALER_DIR/ZscalerRootCertificate.crt"
ZSCALER_BUNDLE="$ZSCALER_DIR/zscalerCAbundle.pem"
AZURE_BUNDLE="$ZSCALER_DIR/azure-cacert.pem"

# Environment variable names and descriptions
# Note: REQUESTS_CA_BUNDLE is handled separately for Azure CLI
ENV_NAMES=(
  "SSL_CERT_FILE"
  "CURL_CA_BUNDLE"
  "NODE_EXTRA_CA_CERTS"
  "GIT_SSL_CAPATH"
  "AWS_CA_BUNDLE"
)

# Check Zscaler setup
check_zscaler_setup() {
  if [ ! -d "$ZSCALER_DIR" ]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[DRY RUN] Warning: Zscaler directory not found at: $ZSCALER_DIR"
      echo "[DRY RUN] In actual run, this would fail. Please ensure Zscaler certificates are installed."
      return 0
    else
      echo "Error: Zscaler directory not found at: $ZSCALER_DIR"
      echo "Please run the Zscaler certificate setup first"
      exit 1
    fi
  fi

  if [ ! -f "$ZSCALER_CERT" ]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[DRY RUN] Warning: Zscaler certificate not found at: $ZSCALER_CERT"
      echo "[DRY RUN] In actual run, this would fail. Please ensure Zscaler certificates are installed."
      return 0
    else
      echo "Error: Zscaler certificate not found at: $ZSCALER_CERT"
      echo "Please run the Zscaler certificate setup first"
      exit 1
    fi
  fi
}

usage() {
  echo "Usage: ${0} [-d|--dry-run] (-a|--azure-cli|-p|--profile)"
  echo ""
  echo "Options:"
  echo "  -a, --azure-cli     Install the certificate bundle for Azure CLI"
  echo "  -d, --dry-run       Show what would be done without making changes (runs even without certificates)"
  echo "  -h, --help          Show this help message"
  echo "  -p, --profile       Append environment variables to shell profile (~/.zshrc or ~/.bash_profile)"
  echo ""
  echo "At least one action (-a or -p) must be specified."
  echo ""
  echo "Examples:"
  echo "  ${0} --dry-run --azure-cli    # Preview Azure CLI cert installation"
  echo "  ${0} --dry-run --profile       # Preview shell profile changes"
  echo "  ${0} --azure-cli --profile     # Install Azure CLI cert and update profile"
  echo "  ${0} --profile                 # Only update shell profile"
  exit 1
}

# Check for source-only mode first
if [[ "$1" == "-s" ]] || [[ "$1" == "--source" ]]; then
  # Exit early when sourced for testing
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

# Process command line arguments
[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case $1 in
  -a | --azure-cli)
    INSTALL_AZURE=1
    shift
    ;;
  -d | --dry-run)
    DRY_RUN=1
    shift
    ;;
  -h | --help)
    usage
    ;;
  -p | --profile)
    UPDATE_PROFILE=1
    shift
    ;;
  *)
    echo "Error: Unknown option: $1"
    usage
    ;;
  esac
done

# Check if any action was specified
if [[ $INSTALL_AZURE -eq 0 ]] && [[ $UPDATE_PROFILE -eq 0 ]]; then
  echo "Error: No action specified."
  echo "You must specify at least one action: --azure-cli or --profile"
  echo ""
  usage
fi

# Check Zscaler setup first, regardless of action
check_zscaler_setup

# Function to detect shell profile
detect_profile() {
  if [[ -n "$SHELL" ]]; then
    if [[ "$SHELL" == *"zsh"* ]] && [[ -f "$HOME/.zshrc" ]]; then
      echo "$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]] && [[ -f "$HOME/.bash_profile" ]]; then
      echo "$HOME/.bash_profile"
    else
      echo ""
    fi
  else
    echo ""
  fi
}

# Function to execute or echo command based on DRY_RUN
execute_cmd() {
  local cmd="$1"
  local msg="$2"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY RUN] Would execute: $cmd"
    [[ -n "$msg" ]] && echo "[DRY RUN] $msg"
  else
    eval "$cmd"
    [[ -n "$msg" ]] && echo "$msg"
  fi
}

if [[ $INSTALL_AZURE -eq 1 ]]; then
  # Check both common Homebrew locations for Azure CLI
  HOMEBREW_PATHS=("/opt/homebrew/Cellar/azure-cli" "/usr/local/Cellar/azure-cli")

  AZURE_PYTHON_PATH=""
  for brew_path in "${HOMEBREW_PATHS[@]}"; do
    if [ -d "$brew_path" ]; then
      FOUND_PATH=$(find "$brew_path" -name "python*" -type d | grep "libexec/lib/python" | head -n 1)
      if [ -n "$FOUND_PATH" ]; then
        AZURE_PYTHON_PATH="$FOUND_PATH"
        echo "Found Azure CLI Python at: $AZURE_PYTHON_PATH"
        break
      fi
    fi
  done

  if [ -z "$AZURE_PYTHON_PATH" ]; then
    echo "Could not find Azure CLI Python installation in any known Homebrew location"
    exit 1
  fi

  # Get certifi's cacert.pem path
  CERTIFI_PATH="$AZURE_PYTHON_PATH/site-packages/certifi/cacert.pem"

  if [ ! -f "$CERTIFI_PATH" ]; then
    echo "Could not find certifi's cacert.pem at $CERTIFI_PATH"
    exit 1
  fi

  # Create the Azure bundle
  execute_cmd "cp '$CERTIFI_PATH' '$AZURE_BUNDLE'" "Copied original certificate bundle to: $AZURE_BUNDLE"

  # Append Zscaler certificate
  execute_cmd "echo '' >> '$AZURE_BUNDLE'" # Add newline for cleaner separation
  execute_cmd "cat '$ZSCALER_CERT' >> '$AZURE_BUNDLE'" "Zscaler certificate appended to bundle"

  echo
  echo "Certificate bundle created at: $AZURE_BUNDLE"
  echo
fi

if [[ $UPDATE_PROFILE -eq 1 ]]; then
  PROFILE=$(detect_profile)
  if [[ -n "$PROFILE" ]]; then
    # Add environment variables
    for env_var in "${ENV_NAMES[@]}"; do
      if grep -q "$env_var=" "$PROFILE"; then
        echo "Environment variable $env_var already exists in $PROFILE"
      else
        execute_cmd "echo 'export $env_var=$ZSCALER_BUNDLE' >> '$PROFILE'" "Added environment variable $env_var to $PROFILE"
      fi
    done

    # Handle REQUESTS_CA_BUNDLE specially for Azure CLI
    if [[ $INSTALL_AZURE -eq 1 ]]; then
      if grep -q "REQUESTS_CA_BUNDLE=" "$PROFILE"; then
        echo "Environment variable REQUESTS_CA_BUNDLE already exists in $PROFILE"
      else
        execute_cmd "echo 'export REQUESTS_CA_BUNDLE=$AZURE_BUNDLE' >> '$PROFILE'" "Added environment variable REQUESTS_CA_BUNDLE for Azure CLI to $PROFILE"
      fi
    fi

    if [[ $DRY_RUN -eq 0 ]]; then
      echo "To apply changes immediately, run:"
      echo "source $PROFILE"
    fi
  else
    echo "Could not detect shell profile. Please manually add these environment variables:"
    for env_var in "${ENV_NAMES[@]}"; do
      echo "export $env_var=$ZSCALER_BUNDLE"
    done
    if [[ $INSTALL_AZURE -eq 1 ]]; then
      echo "export REQUESTS_CA_BUNDLE=$AZURE_BUNDLE"
    fi
  fi
fi
