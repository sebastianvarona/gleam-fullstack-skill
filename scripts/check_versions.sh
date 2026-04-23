#!/bin/bash
# Self-improvement script for gleam-fullstack skill
# This script checks the Lustre package and examples for updated versions
# Run this periodically to keep the skill up to date

set -e

LUSTRE_DIR="/home/svarona/Development/lustre"
SKILL_DIR="/home/svarona/.agents/skills/gleam-fullstack"

echo "🔍 Checking Lustre package for version updates..."
echo ""

# Check if lustre directory exists
if [ ! -d "$LUSTRE_DIR" ]; then
  echo "❌ Lustre directory not found at $LUSTRE_DIR"
  exit 1
fi

# Extract versions from Lustre package
echo "📦 Lustre package versions:"
echo "--------------------------"
grep -E "^gleam_stdlib|^gleam_erlang|^gleam_otp|^gleam_json|^gleam_http|^houdini" "$LUSTRE_DIR/gleam.toml" || true
echo ""

# Check examples for additional patterns
echo "📚 Example dependencies:"
echo "-----------------------"
for example in "$LUSTRE_DIR/examples"/*/*/; do
  if [ -f "$example/gleam.toml" ]; then
    echo ""
    echo "$(basename $(dirname $example))/$(basename $example):"
    grep -E "^lustre|^rsvp|^modem|^gleam_json|^gleam_http|^mist|^gleam_erlang|^gleam_otp|^gleam_stdlib" "$example/gleam.toml" | head -10 || true
  fi
done

echo ""
echo "✅ Version check complete!"
echo ""
echo "Next steps:"
echo "1. Compare these versions with the version table in SKILL.md"
echo "2. Update version constraints in SKILL.md if needed"
echo "3. Update scaffold.sh if new dependencies are required"
echo "4. Run 'gleam run -m scripts/scaffold test-project' to verify"
echo ""
echo "📋 Current skill versions (from SKILL.md):"
echo "------------------------------------------"
grep -E "^\| \`(lustre|gleam_|rsvp|modem|wisp|mist|pog|squirrel|cigogne|envoy|houdini)" "$SKILL_DIR/SKILL.md" || true
