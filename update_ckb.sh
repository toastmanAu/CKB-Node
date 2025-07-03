#!/bin/bash
# CKB Update Script for ARM64 (Ubuntu 22.04)
set -e
TEMP_DIR=$(mktemp -d)
CKB_HOME="/home/orangepi/ckb"
# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT
# Get version from user input
read -p "Enter CKB version to install (e.g., 0.200.0): " VERSION
# Verify version exists on GitHub
RELEASE_URL="https://github.com/nervosnetwork/ckb/releases/download/v${VERSION}/ckb_v${VERSION}_aarch64-unknown-linux-gnu.tar.gz"
if ! curl --output /dev/null --silent --head --fail "$RELEASE_URL"; then
    echo "Error: Version v${VERSION} not found on GitHub. Please verify the version exists."
    exit 1
fi
# Download and extract
echo "Downloading CKB v${VERSION}..."
curl -L "$RELEASE_URL" -o "$TEMP_DIR/ckb.tar.gz" || {
    echo "Failed to download package"
    exit 1
}
echo "Extracting files..."
tar -xzf "$TEMP_DIR/ckb.tar.gz" -C "$TEMP_DIR" || {
    echo "Failed to extract archive"
    exit 1
}
# Verify extracted directory
EXTRACTED_DIR="$TEMP_DIR/ckb_v${VERSION}_aarch64-unknown-linux-gnu"
if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "Error: Extraction directory not found. The package structure might have changed."
    exit 1
fi
# Create target directory if needed
mkdir -p "$CKB_HOME"
# Copy files with overwrite
echo "Updating CKB installation..."
rsync -a --exclude=data --exclude=ckb.toml --exclude=update_ckb.sh --exclude=run_ckb.sh --delete "$EXTRACTED_DIR/" "$CKB_HOME/"
# Set executable permissions
chmod +x "$CKB_HOME/ckb"
echo -e "\nSuccessfully updated CKB to v${VERSION}!"
echo "New version location: $CKB_HOME"
echo "Version verification:"
"$CKB_HOME/ckb" --version
