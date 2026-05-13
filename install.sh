#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# wtm install.sh — Installs the wtm CLI into a directory in your $PATH
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/wtm"

if [[ ! -f "$SOURCE" ]]; then
  echo "❌ Error: wtm script not found at $SOURCE" >&2
  exit 1
fi

# Determine install target
# Prefer ~/.local/bin (no sudo), fallback to /usr/local/bin if writable,
# otherwise ask the user.
INSTALL_DIR=""

if [[ -d "$HOME/.local/bin" && ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  INSTALL_DIR="$HOME/.local/bin"
elif mkdir -p /usr/local/bin &>/dev/null && [[ -w /usr/local/bin ]]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

TARGET="$INSTALL_DIR/wtm"

echo "🌳 Installing wtm..."
echo "   Source: $SOURCE"
echo "   Target: $TARGET"

# Create target directory if needed
mkdir -p "$INSTALL_DIR"

# Copy and make executable
cp "$SOURCE" "$TARGET"
chmod +x "$TARGET"

# Verify it's in PATH
if command -v wtm &>/dev/null; then
  echo ""
  wtm --version 2>/dev/null || true
  echo "✅ wtm installed successfully!"
  echo "   Run 'wtm help' to get started."
else
  echo ""
  echo "✅ wtm copied to $TARGET"
  echo ""
  echo "⚠️  $INSTALL_DIR is not in your \$PATH yet."
  echo "   Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
  echo ""
  echo "     export PATH=\"$INSTALL_DIR:\$PATH\""
  echo ""
  echo "   Then reload your profile or open a new terminal."
fi
