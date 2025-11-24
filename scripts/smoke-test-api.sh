#!/bin/bash
set -e

API_URL=$1

echo "Running smoke tests against $API_URL"

echo "Testing /health endpoint..."
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/health)
if [ "$HEALTH" != "200" ]; then
  echo "Health check failed with status $HEALTH"
  exit 1
fi
echo "✓ Health check passed"

echo "Testing /products endpoint..."
PRODUCTS=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/products)
if [ "$PRODUCTS" != "200" ]; then
  echo "Products endpoint failed with status $PRODUCTS"
  exit 1
fi
echo "✓ Products endpoint passed"

echo "All smoke tests passed!"
