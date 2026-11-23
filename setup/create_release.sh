#!/bin/bash
# MIDIFlow Release Script
# Creates a new release with all platform installers

set -e

echo "========================================="
echo "MIDIFlow Release Script"
echo "========================================="
echo ""

# Check if we're in a git repository
if [ ! -d .git ]; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Get current version
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Current version: $CURRENT_VERSION"
echo ""

# Ask for new version
read -p "Enter new version (e.g., v1.0.0): " NEW_VERSION

if [ -z "$NEW_VERSION" ]; then
    echo "❌ Version cannot be empty"
    exit 1
fi

# Validate version format
if [[ ! "$NEW_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Use v1.0.0 format"
    exit 1
fi

# Check if tag already exists
if git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
    echo "❌ Tag $NEW_VERSION already exists"
    exit 1
fi

echo ""
echo "Creating release $NEW_VERSION..."
echo ""

# Create and push tag
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"
git push origin "$NEW_VERSION"

echo ""
echo "✅ Tag $NEW_VERSION created and pushed!"
echo ""
echo "GitHub Actions will now build all platforms."
echo "Check: https://github.com/felixNT0/midiflow/actions"
echo ""
echo "Release will be available at:"
echo "https://github.com/felixNT0/midiflow/releases/tag/$NEW_VERSION"
