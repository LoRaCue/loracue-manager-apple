.PHONY: help setup install-tools lint format check build-ios build-macos test clean

help:
	@echo "LoRaCue Manager - Build Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make setup          - Install tools and git hooks"
	@echo "  make install-tools  - Install SwiftLint and SwiftFormat"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint           - Run SwiftLint"
	@echo "  make format         - Format code with SwiftFormat"
	@echo "  make check          - Run lint + format check"
	@echo ""
	@echo "Build:"
	@echo "  make build-ios      - Build for iOS Simulator"
	@echo "  make build-macos    - Build for macOS"
	@echo "  make test           - Run all tests"
	@echo "  make clean          - Clean build artifacts"

setup: install-tools
	@echo "Installing git hooks..."
	@chmod +x Scripts/*.sh
	@./Scripts/setup-hooks.sh
	@echo "✓ Setup complete"

install-tools:
	@echo "Checking for Homebrew..."
	@which brew > /dev/null || (echo "Error: Homebrew not found. Install from https://brew.sh" && exit 1)
	@echo "Installing SwiftLint..."
	@brew list swiftlint > /dev/null 2>&1 || brew install swiftlint
	@echo "Installing SwiftFormat..."
	@brew list swiftformat > /dev/null 2>&1 || brew install swiftformat
	@echo "Installing actionlint..."
	@brew list actionlint > /dev/null 2>&1 || brew install actionlint
	@echo "✓ Tools installed"

lint:
	@echo "Running SwiftLint..."
	@swiftlint lint

format:
	@echo "Formatting code..."
	@swiftformat .

check: lint
	@echo "Checking format..."
	@swiftformat --lint .

build-ios:
	@echo "Building for iOS Simulator..."
	@xcodebuild clean build \
		-project LoRaCueManager.xcodeproj \
		-scheme LoRaCueManager \
		-destination "platform=iOS Simulator,name=iPhone 15" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO

build-macos:
	@echo "Building for macOS..."
	@xcodebuild clean build \
		-project LoRaCueManager.xcodeproj \
		-scheme LoRaCueManager \
		-destination "platform=macOS"

test:
	@echo "Running tests..."
	@xcodebuild test \
		-project LoRaCueManager.xcodeproj \
		-scheme LoRaCueManager \
		-destination "platform=macOS" \
		-enableCodeCoverage YES

clean:
	@echo "Cleaning build artifacts..."
	@xcodebuild clean \
		-project LoRaCueManager.xcodeproj \
		-scheme LoRaCueManager
	@rm -rf .build
	@echo "✓ Clean complete"
