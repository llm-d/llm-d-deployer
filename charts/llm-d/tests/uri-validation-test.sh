#!/bin/bash
set -euo pipefail

# Test script for sample application model artifact URI validation
# This script validates that the sample application helper correctly handles different URI types

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Testing sample application model artifact URI validation..."

# Test 1: Test hf:// URI support (should work)
echo "Test 1: Testing hf:// URI support"
helm template test-hf "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/default-values.yaml" \
  --set sampleApplication.enabled=true \
  --set sampleApplication.model.modelArtifactURI="hf://microsoft/DialoGPT-medium" \
  --output-dir /tmp/test-hf 2>/dev/null

if [ -f "/tmp/test-hf/llm-d/templates/sample-application/modelservice.yaml" ]; then
  echo "✅ PASS: hf:// URI correctly handled"
else
  echo "❌ FAIL: hf:// URI not handled correctly"
  exit 1
fi

# Test 2: Test pvc:// URI support (should work)
echo "Test 2: Testing pvc:// URI support"
helm template test-pvc "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/default-values.yaml" \
  --set sampleApplication.enabled=true \
  --set sampleApplication.model.modelArtifactURI="pvc://my-model-pvc/model" \
  --output-dir /tmp/test-pvc 2>/dev/null

if [ -f "/tmp/test-pvc/llm-d/templates/sample-application/modelservice.yaml" ]; then
  echo "✅ PASS: pvc:// URI correctly handled"
else
  echo "❌ FAIL: pvc:// URI not handled correctly"
  exit 1
fi

# Test 3: Test s3:// URI without runai_streamer (should fail)
echo "Test 3: Testing s3:// URI without runai_streamer (should fail)"
set +e
helm template test-s3-fail "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/default-values.yaml" \
  --set sampleApplication.enabled=true \
  --set sampleApplication.model.modelArtifactURI="s3://my-bucket/model" \
  --output-dir /tmp/test-s3-fail >/dev/null 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
  echo "✅ PASS: s3:// URI correctly rejected without runai_streamer"
else
  echo "❌ FAIL: s3:// URI should have been rejected without runai_streamer"
  exit 1
fi

# Test 4: Test s3:// URI with runai_streamer (should work)
echo "Test 4: Testing s3:// URI with runai_streamer (should work)"
helm template test-s3-success "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/runai-streamer-values.yaml" \
  --set sampleApplication.enabled=true \
  --set sampleApplication.model.modelArtifactURI="s3://my-bucket/model" \
  --output-dir /tmp/test-s3-success 2>/dev/null

if [ -f "/tmp/test-s3-success/llm-d/templates/sample-application/modelservice.yaml" ]; then
  echo "✅ PASS: s3:// URI correctly handled with runai_streamer"
else
  echo "❌ FAIL: s3:// URI not handled correctly with runai_streamer"
  exit 1
fi

# Test 5: Test gcs:// URI with runai_streamer (should work)
echo "Test 5: Testing gcs:// URI with runai_streamer (should work)"
helm template test-gcs-success "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/runai-streamer-values.yaml" \
  --set sampleApplication.enabled=true \
  --set sampleApplication.model.modelArtifactURI="gcs://my-bucket/model" \
  --output-dir /tmp/test-gcs-success 2>/dev/null

if [ -f "/tmp/test-gcs-success/llm-d/templates/sample-application/modelservice.yaml" ]; then
  echo "✅ PASS: gcs:// URI correctly handled with runai_streamer"
else
  echo "❌ FAIL: gcs:// URI not handled correctly with runai_streamer"
  exit 1
fi

# Test 6: Test that loadFormat is correctly passed to sample application
echo "Test 6: Testing loadFormat configuration in sample application"

# Check that with runai_streamer, the load-format argument is passed
SAMPLE_FILE_RUNAI="/tmp/test-s3-success/llm-d/templates/sample-application/modelservice.yaml"
if grep -q -- "--load-format" "${SAMPLE_FILE_RUNAI}" && grep -q "runai_streamer" "${SAMPLE_FILE_RUNAI}"; then
  echo "✅ PASS: Sample application correctly includes load-format argument"
else
  echo "❌ FAIL: Sample application should include load-format argument"
  exit 1
fi

# Check that runai_streamer environment variables are included
if grep -q "RUNAI_STREAMER_CONCURRENCY" "${SAMPLE_FILE_RUNAI}"; then
  echo "✅ PASS: Sample application includes runai_streamer environment variables"
else
  echo "❌ FAIL: Sample application should include runai_streamer environment variables"
  exit 1
fi

# Check that the modelArtifacts URI is set correctly
if grep -q "uri: s3://my-bucket/model" "${SAMPLE_FILE_RUNAI}"; then
  echo "✅ PASS: Sample application correctly sets modelArtifacts URI"
else
  echo "❌ FAIL: Sample application should set modelArtifacts URI correctly"
  exit 1
fi

# Test 7: Test unknown URI scheme without runai_streamer (should fail)
echo "Test 7: Testing unknown URI scheme without runai_streamer (should fail)"
set +e
helm template test-unknown-fail "${CHART_DIR}" \
  --values "${CHART_DIR}/ci/default-values.yaml" \
  --set sampleApplication.enabled=true \
  --set sampleApplication.model.modelArtifactURI="unknown://some-path" \
  --output-dir /tmp/test-unknown-fail >/dev/null 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
  echo "✅ PASS: Unknown URI scheme correctly rejected without runai_streamer"
else
  echo "❌ FAIL: Unknown URI scheme should have been rejected without runai_streamer"
  exit 1
fi

# Cleanup
rm -rf /tmp/test-hf /tmp/test-pvc /tmp/test-s3-fail /tmp/test-s3-success /tmp/test-gcs-success /tmp/test-unknown-fail

echo ""
echo "🎉 All URI validation tests passed!"
