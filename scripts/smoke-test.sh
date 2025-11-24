#!/bin/bash
set -e

API_URL=$1
FRONTEND_URL=$2

echo "Running comprehensive smoke tests..."
echo "API URL: $API_URL"
echo "Frontend URL: $FRONTEND_URL"

# Test API
echo "=== API Smoke Tests ==="
./scripts/smoke-test-api.sh $API_URL

# Test Frontend
echo "=== Frontend Smoke Tests ==="
./scripts/smoke-test-frontend.sh $FRONTEND_URL

echo "=== All smoke tests passed! ==="