#!/bin/bash
#
# SSD Firewall CLI Installer (ARM/AMD + Docker buildx safe)
#

set -e

REPO="OpsMx/ssd-scanner-cli-public"
TAG_PREFIX="firewall-"
BINARY_NAME="ssd-firewall-cli"
INSTALL_DIR="/usr/local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

##########################################
# Architecture Detection
##########################################
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac
}

##########################################
# OS Detection
##########################################
detect_os() {
    case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
        linux) echo "linux" ;;
        *) error "Only Linux is supported" ;;
    esac
}

##########################################
# Fetch latest tag with firewall- prefix
##########################################
get_latest_version() {
    local url="https://api.github.com/repos/${REPO}/releases"

    local tag=$(curl -sL "$url" | grep '"tag_name":' | grep "${TAG_PREFIX}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    [ -z "$tag" ] && error "Failed fetching latest version"

    echo "${tag#${TAG_PREFIX}}"
}

##########################################
# Download Utility
##########################################
download() {
    curl -sL "$1" -o "$2"
}

##########################################
# Checksum Verification
##########################################
verify_checksum() {
    info "Verifying checksum..."
    local tmp=$(mktemp)
    download "$2" "$tmp"

    local expected=$(grep "$3" "$tmp" | awk '{print $1}')
    local actual=$(sha256sum "$1" | awk '{print $1}')

    rm -f "$tmp"

    [ "$expected" != "$actual" ] && error "Checksum mismatch!"

    info "Checksum verified"
}

##########################################
# Skip sudo in Docker / buildx environment
##########################################
is_docker() {
    # non-interactive + root → safe signal
    if [ ! -t 0 ] || [ "$(id -u)" = "0" ]; then
        return 0
    fi
    return 1
}

##########################################
# Install Binary (no sudo needed in Docker)
##########################################
install_binary() {
    local src="$1"
    local dest="$2"

    # running inside Docker build = root + nosuid → avoid sudo
    if is_docker; then
        info "Running in Docker / non-interactive mode → skipping sudo"
        mv "$src" "$dest"
        chmod +x "$dest"
        return
    fi

    # normal system install
    if [ -w "$(dirname "$dest")" ]; then
        mv "$src" "$dest"
        chmod +x "$dest"
    else
        if command -v sudo >/dev/null 2>&1; then
            sudo mv "$src" "$dest"
            sudo chmod +x "$dest"
        else
            error "Cannot write to $dest and sudo not available"
        fi
    fi
}

##########################################
# MAIN
##########################################
main() {
    echo ""
    echo "=========================================="
    echo "  SSD Firewall CLI Installer"
    echo "=========================================="
    echo ""

    local version=${1:-$(get_latest_version)}
    info "Installing version: $version"

    local os=$(detect_os)
    local arch=$(detect_arch)
    info "Detected system: $os-$arch"

    # File names
    local tag="${TAG_PREFIX}${version}"
    local bin="${BINARY_NAME}-${os}-${arch}"
    local url="https://github.com/${REPO}/releases/download/${tag}/${bin}"
    local csurl="https://github.com/${REPO}/releases/download/${tag}/checksums.txt"

    # Temp location
    local tmpdir=$(mktemp -d)
    local tmpbin="${tmpdir}/${bin}"

    # Download
    info "Downloading ${bin}..."
    download "$url" "$tmpbin"
    [ ! -s "$tmpbin" ] && error "Download failed"

    # Verify checksum
    verify_checksum "$tmpbin" "$csurl" "$bin"

    # Install
    local install_path="${INSTALL_DIR}/${BINARY_NAME}"
    info "Installing to ${install_path}"

    install_binary "$tmpbin" "$install_path"

    rm -rf "$tmpdir"

    info "Installed successfully"
    "$install_path" version || true
}

main "$@"
