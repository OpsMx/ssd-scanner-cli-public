#!/bin/bash

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
URL="https://github.com/OpsMx/ssd-scanner-cli-public/releases/latest/download/ssd-scanner-cli-${ARCH}"

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
