#!/bin/bash
# MIDIFlow iOS Build Script
# This script helps build the iOS app with proper signing

set -e

echo "========================================="
echo "MIDIFlow iOS Build Script"
echo "========================================="
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed."
    echo "   Download from: https://developer.apple.com/xcode/"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed."
    echo "   Install from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "⚠️  CocoaPods is not installed."
    echo "   Installing CocoaPods..."
    sudo gem install cocoapods
fi

# Navigate to project directory
cd "$(dirname "$0")/.."

echo "📱 Building iOS app..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Install iOS pods
echo "🍫 Installing iOS dependencies..."
cd ios
pod install
cd ..

# Build iOS app
echo "🔨 Building iOS app..."
flutter build ios --release

# Open in Xcode for signing
echo ""
echo "========================================="
echo "✅ Build complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Select your Team in Signing & Capabilities"
echo "3. Connect your iPhone/iPad"
echo "4. Click Run to install on device"
echo ""
echo "For distribution:"
echo "- Create .ipa: flutter build ipa --release"
echo "- Or use Xcode → Product → Archive"
echo ""
echo "See iOS_SETUP.txt for detailed instructions."
