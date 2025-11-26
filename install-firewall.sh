#!/bin/bash
#
# SSD Firewall CLI Installer
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/OpsMx/ssd-scanner-cli-public/main/install-firewall.sh | bash
#
# Or with a specific version:
#   curl -sSL https://raw.githubusercontent.com/OpsMx/ssd-scanner-cli-public/main/install-firewall.sh | bash -s -- v1.0.0
#

set -e

REPO="OpsMx/ssd-scanner-cli-public"
TAG_PREFIX="firewall-"
BINARY_NAME="ssd-firewall-cli"
INSTALL_DIR="/usr/local/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Detect architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            error "Unsupported architecture: $arch. Only amd64 and arm64 are supported."
            ;;
    esac
}

# Detect OS
detect_os() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case $os in
        linux)
            echo "linux"
            ;;
        *)
            error "Unsupported OS: $os. Only Linux is supported."
            ;;
    esac
}

# Get latest release version from GitHub API
# Filters releases to only those with firewall- prefix
get_latest_version() {
    local releases_url="https://api.github.com/repos/${REPO}/releases"
    local version
    local tag

    if command -v curl &> /dev/null; then
        # Get all releases and find the latest with firewall- prefix
        tag=$(curl -sL "$releases_url" | grep '"tag_name":' | grep "${TAG_PREFIX}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget &> /dev/null; then
        tag=$(wget -qO- "$releases_url" | grep '"tag_name":' | grep "${TAG_PREFIX}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    else
        error "Neither curl nor wget found. Please install one of them."
    fi

    if [ -z "$tag" ]; then
        error "Could not fetch latest version. Please specify a version manually (e.g., v1.0.0)."
    fi

    # Strip the prefix to get the version (firewall-v1.0.0 -> v1.0.0)
    version="${tag#${TAG_PREFIX}}"
    echo "$version"
}

# Download file
download() {
    local url=$1
    local output=$2

    if command -v curl &> /dev/null; then
        curl -sL "$url" -o "$output"
    elif command -v wget &> /dev/null; then
        wget -q "$url" -O "$output"
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
}

# Verify checksum
verify_checksum() {
    local binary_path=$1
    local checksums_url=$2
    local binary_name=$3

    info "Verifying checksum..."

    local temp_checksums=$(mktemp)
    download "$checksums_url" "$temp_checksums"

    local expected_checksum=$(grep "$binary_name" "$temp_checksums" | awk '{print $1}')
    local actual_checksum=$(sha256sum "$binary_path" | awk '{print $1}')

    rm -f "$temp_checksums"

    if [ "$expected_checksum" != "$actual_checksum" ]; then
        error "Checksum verification failed!
Expected: $expected_checksum
Actual:   $actual_checksum"
    fi

    info "Checksum verified successfully"
}

# Check for existing installation and prompt for confirmation
check_existing_version() {
    local install_path=$1
    local new_version=$2

    if [ -f "$install_path" ]; then
        local old_version=$("$install_path" version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")

        echo ""
        warn "Existing installation detected!"
        echo ""
        echo "  Current version: ${RED}${old_version}${NC}"
        echo "  New version:     ${GREEN}${new_version}${NC}"
        echo "  Location:        ${install_path}"
        echo ""

        # Skip confirmation if running non-interactively (piped)
        if [ -t 0 ]; then
            read -p "Do you want to replace the existing version? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Installation cancelled by user"
                exit 0
            fi
        else
            info "Non-interactive mode: proceeding with replacement"
        fi

        info "Removing old version..."
        if [ -w "$install_path" ]; then
            rm -f "$install_path"
        elif command -v sudo &> /dev/null; then
            sudo rm -f "$install_path"
        else
            error "Cannot remove old version at $install_path. Please remove it manually."
        fi
        info "Old version removed"
    fi
}

# Main installation
main() {
    echo ""
    echo "=========================================="
    echo "  SSD Firewall CLI Installer"
    echo "=========================================="
    echo ""

    # Get version (from argument or latest)
    local version=${1:-$(get_latest_version)}
    info "Installing version: $version"

    # Detect system
    local os=$(detect_os)
    local arch=$(detect_arch)
    info "Detected system: $os-$arch"

    # Check for existing installation
    if command -v ${BINARY_NAME} &> /dev/null; then
        local existing_path=$(which ${BINARY_NAME})
        check_existing_version "$existing_path" "$version"
    elif [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        check_existing_version "${INSTALL_DIR}/${BINARY_NAME}" "$version"
    elif [ -f "${HOME}/.local/bin/${BINARY_NAME}" ]; then
        check_existing_version "${HOME}/.local/bin/${BINARY_NAME}" "$version"
    fi

    # Construct download URLs (tag includes prefix: firewall-v1.0.0)
    local tag="${TAG_PREFIX}${version}"
    local binary_filename="${BINARY_NAME}-${os}-${arch}"
    local download_url="https://github.com/${REPO}/releases/download/${tag}/${binary_filename}"
    local checksums_url="https://github.com/${REPO}/releases/download/${tag}/checksums.txt"

    # Create temp directory
    local temp_dir=$(mktemp -d)
    local temp_binary="${temp_dir}/${binary_filename}"

    # Download binary
    info "Downloading ${binary_filename}..."
    download "$download_url" "$temp_binary"

    if [ ! -f "$temp_binary" ] || [ ! -s "$temp_binary" ]; then
        rm -rf "$temp_dir"
        error "Failed to download binary. Please check the version and try again."
    fi

    # Verify checksum
    verify_checksum "$temp_binary" "$checksums_url" "$binary_filename"

    # Make executable
    chmod +x "$temp_binary"

    # Determine install location
    if [ -w "$INSTALL_DIR" ]; then
        local install_path="${INSTALL_DIR}/${BINARY_NAME}"
    elif command -v sudo &> /dev/null; then
        info "Requires sudo to install to ${INSTALL_DIR}"
        local install_path="${INSTALL_DIR}/${BINARY_NAME}"
        sudo mv "$temp_binary" "$install_path"
        sudo chmod +x "$install_path"
        rm -rf "$temp_dir"
        info "Installed to: $install_path"
        verify_installation "$install_path"
        return
    else
        # Fallback to user directory
        INSTALL_DIR="${HOME}/.local/bin"
        mkdir -p "$INSTALL_DIR"
        local install_path="${INSTALL_DIR}/${BINARY_NAME}"
        warn "Cannot write to /usr/local/bin, installing to ${INSTALL_DIR}"
        warn "Make sure ${INSTALL_DIR} is in your PATH"
    fi

    # Move binary to install location
    mv "$temp_binary" "$install_path"
    chmod +x "$install_path"

    # Cleanup
    rm -rf "$temp_dir"

    info "Installed to: $install_path"
    verify_installation "$install_path"
}

verify_installation() {
    local install_path=$1

    echo ""
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo ""

    # Verify installation
    if [ -x "$install_path" ]; then
        info "Verifying installation..."
        "$install_path" version
        echo ""
        info "Run '${BINARY_NAME} --help' to get started"
    else
        warn "Binary installed but may not be in PATH"
        info "Add ${INSTALL_DIR} to your PATH or run: $install_path --help"
    fi
}

main "$@"
