#!/bin/bash

echo "Running pre-push checks..."

# Run SwiftLint in strict mode
echo "→ Running SwiftLint (strict)..."
swiftlint lint --strict --quiet
if [ $? -ne 0 ]; then
    echo "❌ SwiftLint failed with warnings. Fix all warnings before pushing."
    exit 1
fi

# Build for macOS
echo "→ Building for macOS..."
xcodebuild build \
    -workspace LoRaCueManager.xcworkspace \
    -scheme LoRaCueManager \
    -destination "platform=macOS" \
    > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ macOS build failed"
    exit 1
fi

# Build for iOS Simulator
# echo "→ Building for iOS Simulator..."
# xcodebuild build \
#     -workspace LoRaCueManager.xcworkspace \
#     -scheme LoRaCueManager \
#     -destination "platform=iOS Simulator,name=iPhone 16e,OS=18.6" \
#     > /dev/null 2>&1
#
# if [ $? -ne 0 ]; then
#     echo "❌ iOS build failed"
#     exit 1
# fi

echo "✓ Pre-push checks passed"
exit 0
