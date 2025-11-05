#!/bin/bash

echo "Running pre-push checks..."

# Build for macOS
echo "→ Building for macOS..."
xcodebuild clean build \
    -project LoRaCueManager.xcodeproj \
    -scheme LoRaCueManager \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ macOS build failed"
    exit 1
fi

# Build for iOS Simulator
echo "→ Building for iOS Simulator..."
xcodebuild clean build \
    -project LoRaCueManager.xcodeproj \
    -scheme LoRaCueManager \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ iOS build failed"
    exit 1
fi

echo "✓ Pre-push checks passed"
exit 0
