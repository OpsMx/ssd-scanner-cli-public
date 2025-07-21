#!/bin/bash

# Function to install sudo and curl
install_sudo_and_curl() {
  # Check if both sudo and curl are installed
  if ! command -v sudo >/dev/null || ! command -v curl >/dev/null; then
    if command -v apt >/dev/null; then
      echo "Detected Debian-based system. Installing sudo and curl using apt."
      apt update && apt install -y sudo curl
    elif command -v yum >/dev/null; then
      echo "Detected Red Hat-based system. Installing sudo and curl using yum."
      yum install -y sudo curl
    elif command -v dnf >/dev/null; then
      echo "Detected Fedora-based system. Installing sudo and curl using dnf."
      dnf install -y sudo curl
    elif command -v zypper >/dev/null; then
      echo "Detected openSUSE-based system. Installing sudo and curl using zypper."
      zypper install -y sudo curl
    elif command -v apk >/dev/null; then
      echo "Detected Alpine Linux system. Installing sudo and curl using apk."
      apk add --no-cache sudo curl
    elif command -v pacman >/dev/null; then
      echo "Detected Arch-based system. Installing sudo and curl using pacman."
      pacman -Sy --noconfirm sudo curl
    else
      echo "Package manager not found. Please install sudo and curl manually."
      exit 1
    fi
  fi
}

# Check if sudo or curl is installed
install_sudo_and_curl

# Re-check if sudo is now available
if ! command -v sudo >/dev/null; then
  echo "Failed to install sudo. Please install it manually and rerun the script."
  exit 1
fi

# Detect system architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64)
    ARCH="arm64"
    ;;
  armv7l)
    ARCH="armv7"
    ;;
  i386)
    ARCH="386"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Define the URL
URL="https://github.com/OpsMx/ssd-scanner-cli-public/releases/download/v2025.07.17/ssd-scanner-cli-${ARCH}"

# Download the CLI
echo "Downloading ssd-scanner-cli for architecture: $ARCH"
sudo curl -L -o ssd-scanner-cli "$URL"
if [ $? -ne 0 ]; then
  echo "Failed to download ssd-scanner-cli. Exiting."
  exit 1
fi

# Make it executable
echo "Making ssd-scanner-cli executable"
sudo chmod +x ./ssd-scanner-cli

# Copy to /usr/local/bin
echo "Copying ssd-scanner-cli to /usr/local/bin"
sudo cp ssd-scanner-cli /usr/local/bin

# Verify installation
if command -v ssd-scanner-cli >/dev/null 2>&1; then
  echo "ssd-scanner-cli installed successfully!"
else
  echo "Installation failed. Please check manually."
  exit 1
fi
