#!/bin/bash
set -euo pipefail

# Test script for loadFormat and runai_streamer functionality
# This script validates that the Helm templates render correctly with various loadFormat configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Testing loadFormat and runai_streamer functionality..."

# Test 1: Default behavior (no loadFormat specified)
echo "Test 1: Testing default behavior (no loadFormat)"
helm template test-default "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/default-values.yaml" \
  --output-dir /tmp/test-default 2>/dev/null

# Verify loadFormat is not present in default case
if grep -q "load-format" /tmp/test-default/llm-d/templates/modelservice/presets/basic-gpu-preset.yaml; then
  echo "❌ FAIL: load-format should not be present in default configuration"
  exit 1
else
  echo "✅ PASS: load-format correctly omitted in default configuration"
fi

# Test 2: RunAI Streamer configuration
echo "Test 2: Testing runai_streamer configuration"
helm template test-runai "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/runai-streamer-values.yaml" \
  --output-dir /tmp/test-runai 2>/dev/null

PRESET_FILE="/tmp/test-runai/llm-d/templates/modelservice/presets/basic-gpu-preset.yaml"

# Check that load-format is properly set
if grep -q -- "--load-format" "${PRESET_FILE}" && grep -q "runai_streamer" "${PRESET_FILE}"; then
  echo "✅ PASS: load-format argument correctly added"
else
  echo "❌ FAIL: load-format argument not found in preset"
  exit 1
fi

# Check for model-loader-extra-config
if grep -q -- "--model-loader-extra-config" "${PRESET_FILE}"; then
  echo "✅ PASS: model-loader-extra-config argument correctly added"
else
  echo "❌ FAIL: model-loader-extra-config argument not found"
  exit 1
fi

# Check for RunAI Streamer environment variables
EXPECTED_ENV_VARS=(
  "RUNAI_STREAMER_CONCURRENCY"
  "RUNAI_STREAMER_CHUNK_BYTESIZE"
  "RUNAI_STREAMER_MEMORY_LIMIT"
  "AWS_ENDPOINT_URL"
  "AWS_CA_BUNDLE"
  "RUNAI_STREAMER_S3_USE_VIRTUAL_ADDRESSING"
)

for env_var in "${EXPECTED_ENV_VARS[@]}"; do
  if grep -q "${env_var}" "${PRESET_FILE}"; then
    echo "✅ PASS: Environment variable ${env_var} found"
  else
    echo "❌ FAIL: Environment variable ${env_var} not found"
    exit 1
  fi
done

# Check for extra args
if grep -q -- "--custom-arg1" "${PRESET_FILE}" && grep -q "value1" "${PRESET_FILE}"; then
  echo "✅ PASS: Extra args correctly rendered"
else
  echo "❌ FAIL: Extra args not found"
  exit 1
fi

# Check for extra environment variables
if grep -q "TEST_ENV_VAR" "${PRESET_FILE}" && grep -q "test-value" "${PRESET_FILE}"; then
  echo "✅ PASS: Extra environment variables correctly rendered"
else
  echo "❌ FAIL: Extra environment variables not found"
  exit 1
fi

# Test 3: Sample application with runai_streamer
echo "Test 3: Testing sample application with runai_streamer"
helm template test-sample "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/runai-streamer-values.yaml" \
  --set sampleApplication.enabled=true \
  --set sampleApplication.model.modelArtifactURI="s3://test-bucket/model" \
  --output-dir /tmp/test-sample 2>/dev/null

SAMPLE_FILE="/tmp/test-sample/llm-d/templates/sample-application/modelservice.yaml"

# Check that sample application gets the loadFormat configuration
if grep -q -- "--load-format" "${SAMPLE_FILE}" && grep -q "runai_streamer" "${SAMPLE_FILE}"; then
  echo "✅ PASS: Sample application load-format correctly configured"
else
  echo "❌ FAIL: Sample application load-format not configured"
  exit 1
fi

# Test 4: Template validation for all presets
echo "Test 4: Testing all presets render correctly with runai_streamer"
PRESET_FILES=(
  "basic-gpu-preset.yaml"
  "basic-gpu-with-nixl-preset.yaml"
  "basic-gpu-with-nixl-and-redis-lookup-preset.yaml"
)

for preset in "${PRESET_FILES[@]}"; do
  preset_path="/tmp/test-runai/llm-d/templates/modelservice/presets/${preset}"
  if [ -f "${preset_path}" ]; then
    if grep -q -- "--load-format" "${preset_path}" && grep -q "RUNAI_STREAMER_CONCURRENCY" "${preset_path}"; then
      echo "✅ PASS: Preset ${preset} correctly configured"
    else
      echo "❌ FAIL: Preset ${preset} missing required configurations"
      exit 1
    fi
  else
    echo "❌ FAIL: Preset file ${preset} not found"
    exit 1
  fi
done

# Test 5: Validate JSON structure in model-loader-extra-config
echo "Test 5: Testing JSON structure in model-loader-extra-config"
# Extract the JSON from the rendered template and validate it
JSON_LINE=$(grep -A1 -- "--model-loader-extra-config" "${PRESET_FILE}" | tail -n1)
if echo "${JSON_LINE}" | grep -q 'concurrency.*32' && echo "${JSON_LINE}" | grep -q 'memory_limit.*1073741824' && echo "${JSON_LINE}" | grep -q 'pattern.*custom-model-rank'; then
  echo "✅ PASS: JSON structure in model-loader-extra-config is correct"
else
  echo "❌ FAIL: JSON structure in model-loader-extra-config is incorrect"
  echo "Found: ${JSON_LINE}"
  exit 1
fi

# Cleanup
rm -rf /tmp/test-default /tmp/test-runai /tmp/test-sample

echo ""
echo "🎉 All tests passed! loadFormat and runai_streamer functionality is working correctly."
