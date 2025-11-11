#!/bin/sh

# Xcode Cloud post-clone script
# Sets version numbers to match GitHub Actions workflow

set -e

echo "Setting version numbers for Xcode Cloud build..."

# Get version from git tag or use default
if git describe --tags --exact-match 2>/dev/null; then
    VERSION=$(git describe --tags --exact-match | sed 's/^v//')
    echo "Using tag version: $VERSION"
else
    VERSION="1.0.0"
    echo "No tag found, using default version: $VERSION"
fi

# Get build number from git commit count
BUILD_NUMBER=$(git rev-list --count HEAD)
echo "Build number: $BUILD_NUMBER"

# Update xcconfig file
XCCONFIG_PATH="$CI_WORKSPACE/Config/Shared.xcconfig"
if [ -f "$XCCONFIG_PATH" ]; then
    sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION/" "$XCCONFIG_PATH"
    sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$XCCONFIG_PATH"
    echo "Updated $XCCONFIG_PATH"
    echo "  MARKETING_VERSION = $VERSION"
    echo "  CURRENT_PROJECT_VERSION = $BUILD_NUMBER"
else
    echo "Warning: $XCCONFIG_PATH not found"
    exit 1
fi

echo "Version setup complete"
