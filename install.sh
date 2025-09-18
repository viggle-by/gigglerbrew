#!/bin/bash
set -e

GIGGLER_PREFIX="/opt/giggler"

if [ -d "$GIGGLER_PREFIX" ]; then
  echo "Giggler already installed at $GIGGLER_PREFIX"
  exit 0
fi

echo "Installing Giggler to $GIGGLER_PREFIX"

# Clone the repository
git clone https://github.com/yourusername/gigglercraft.git "$GIGGLER_PREFIX"

echo "Giggler installed!"

echo "Add Giggler to your PATH by adding the following line to your shell profile:"
echo "  export PATH=\"$GIGGLER_PREFIX/bin:\$PATH\""

echo "To start using giggler, run:"
echo "  source ~/.bash_profile  # or your shell profile"
echo "  giggler help"