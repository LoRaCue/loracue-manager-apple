#!/bin/bash

HOOKS_DIR=".git/hooks"
SCRIPTS_DIR="Scripts"

echo "Installing git hooks..."

# Install commit-msg hook
cat > "$HOOKS_DIR/commit-msg" << 'EOF'
#!/bin/bash
exec ./Scripts/validate-commit-msg.sh "$1"
EOF
chmod +x "$HOOKS_DIR/commit-msg"
echo "✓ Installed commit-msg hook"

# Install pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
exec ./Scripts/pre-commit-checks.sh
EOF
chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ Installed pre-commit hook"

# Install pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
exec ./Scripts/pre-push-checks.sh
EOF
chmod +x "$HOOKS_DIR/pre-push"
echo "✓ Installed pre-push hook"

echo "✓ Git hooks installed successfully"
