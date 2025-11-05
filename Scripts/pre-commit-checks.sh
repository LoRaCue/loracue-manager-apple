#!/bin/bash

echo "Running pre-commit checks..."

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "⚠️  SwiftLint not installed. Run: make install-tools"
    exit 1
fi

# Check if SwiftFormat is installed
if ! command -v swiftformat &> /dev/null; then
    echo "⚠️  SwiftFormat not installed. Run: make install-tools"
    exit 1
fi

# Run SwiftLint
echo "→ Running SwiftLint..."
swiftlint lint --quiet
if [ $? -ne 0 ]; then
    echo "❌ SwiftLint failed. Fix issues or run: make lint"
    exit 1
fi

# Run SwiftFormat check
echo "→ Checking code format..."
swiftformat --lint . > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Code formatting issues found. Run: make format"
    exit 1
fi

# Check if GitHub workflow files changed
WORKFLOW_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "^.github/workflows/.*\.yml$")

if [ -n "$WORKFLOW_FILES" ]; then
    echo "→ GitHub workflow files changed, checking with actionlint..."
    
    # Check if actionlint is installed
    if ! command -v actionlint &> /dev/null; then
        echo "⚠️  actionlint not installed. Install with: brew install actionlint"
        echo "⚠️  Skipping workflow validation (install actionlint to enable)"
    else
        for file in $WORKFLOW_FILES; do
            echo "   Checking $file..."
            actionlint "$file"
            if [ $? -ne 0 ]; then
                echo "❌ actionlint failed for $file"
                exit 1
            fi
        done
        echo "✓ GitHub workflows validated"
    fi
fi

echo "✓ Pre-commit checks passed"
exit 0
