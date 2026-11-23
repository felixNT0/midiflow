#!/bin/bash
# MIDIFlow Linux Build Script
# Run this on a Linux machine to build the Linux installer

set -e

echo "========================================="
echo "MIDIFlow Linux Build Script"
echo "========================================="
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed."
    echo "   Install from: https://flutter.dev/docs/get-started/install/linux"
    exit 1
fi

# Navigate to project directory
cd "$(dirname "$0")/.."

echo "[1/5] Cleaning previous builds..."
flutter clean

echo "[2/5] Getting dependencies..."
flutter pub get

echo "[3/5] Building Linux release..."
flutter build linux --release

echo "[4/5] Packaging..."
mkdir -p setup/app-installers/linux

# Create tarball
tar -czf setup/app-installers/linux/MIDIFlow-linux.tar.gz -C build/linux/x64/release/bundle .

echo "[5/5] Done!"
echo ""
echo "Linux installer created at:"
echo "setup/app-installers/linux/MIDIFlow-linux.tar.gz"
echo ""
echo "To install:"
echo "tar -xzf MIDIFlow-linux.tar.gz"
echo "./midiflow"
