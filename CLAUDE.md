# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Bash shell script utility for managing Zscaler SSL certificates on macOS. The project helps developers resolve SSL certificate issues when using command-line tools behind a corporate Zscaler proxy.

## Key Files

- `zscaler-mac.sh` - Main executable script that manages SSL certificates
- `README.md` - Comprehensive documentation with installation instructions and usage examples

## Development Commands

### Linting
Use shellcheck to validate the shell script:
```bash
shellcheck zscaler-mac.sh
```

### Testing
Run the BATS test suite:
```bash
# Run all tests
./_test/run_tests.sh

# Run tests directly with BATS
cd _test && bats zscaler-mac.bats

# Run with verbose output for debugging
bats _test/zscaler-mac.bats --verbose-run
```

### Running the Script
```bash
# Display help
./zscaler-mac.sh --help

# Dry run (preview changes)
./zscaler-mac.sh --dry-run

# Create Azure CLI certificate bundle
./zscaler-mac.sh --azure-cli

# Update shell profile with environment variables
./zscaler-mac.sh --profile

# Full setup
./zscaler-mac.sh --azure-cli --profile
```

## Architecture

The script follows a simple, single-file architecture with these key components:

1. **Certificate Management**: Expects Zscaler certificates to be pre-installed in `$HOME/.zscalerCerts/`
2. **Environment Configuration**: Sets SSL certificate environment variables for various tools (curl, git, node, AWS CLI, Azure CLI)
3. **Azure CLI Integration**: Creates a combined certificate bundle specifically for Azure CLI's Python requests library
4. **Shell Profile Updates**: Modifies shell profiles (.zshrc, .bashrc) to persist environment variables

## Design Principles

- **Idempotent**: Safe to run multiple times without side effects
- **Dry-run capability**: Preview changes before applying them
- **Shellcheck compliant**: Follows shell scripting best practices
- **macOS focused**: Specifically designed for macOS environments

## Certificate Dependencies

The script requires Zscaler root certificates to be present in `$HOME/.zscalerCerts/` before running. These certificates must be obtained from your organization's IT department.

## CI/CD

GitHub Actions workflow (`.github/workflows/test.yml`) runs:
1. **Shellcheck** - Validates shell script syntax on Ubuntu
2. **BATS tests** - Runs the test suite on macOS with mock certificates