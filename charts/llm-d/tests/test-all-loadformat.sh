#!/bin/bash
set -euo pipefail

# Comprehensive test runner for loadFormat and runai_streamer functionality
# This script runs all tests related to the PR changes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Running comprehensive tests for loadFormat and runai_streamer functionality"
echo "=========================================================================="

# Run loadFormat template rendering tests
echo ""
echo "📋 Running loadFormat template rendering tests..."
if "${SCRIPT_DIR}/loadformat-test.sh"; then
  echo "✅ loadFormat template rendering tests: PASSED"
else
  echo "❌ loadFormat template rendering tests: FAILED"
  exit 1
fi

# Run URI validation tests
echo ""
echo "🔗 Running URI validation tests..."
if "${SCRIPT_DIR}/uri-validation-test.sh"; then
  echo "✅ URI validation tests: PASSED"
else
  echo "❌ URI validation tests: FAILED"
  exit 1
fi

echo ""
echo "🎉 All tests passed! The loadFormat and runai_streamer implementation is working correctly."
echo ""
echo "Summary of tested functionality:"
echo "- ✅ loadFormat configuration in values.yaml"
echo "- ✅ runai_streamer environment variables rendering"
echo "- ✅ model-loader-extra-config JSON generation"
echo "- ✅ All modelservice presets support runai_streamer"
echo "- ✅ Sample application integration with runai_streamer"
echo "- ✅ URI validation for hf://, pvc://, s3://, gcs:// schemes"
echo "- ✅ Error handling for unsupported URI schemes"
echo "- ✅ Backward compatibility with existing configurations"
