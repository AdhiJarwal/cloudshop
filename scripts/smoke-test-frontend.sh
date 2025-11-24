#!/bin/bash
set -e

FRONTEND_URL=$1

echo "Running frontend smoke tests against $FRONTEND_URL"

echo "Testing frontend availability..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $FRONTEND_URL)
if [ "$STATUS" != "200" ]; then
  echo "Frontend check failed with status $STATUS"
  exit 1
fi
echo "✓ Frontend is accessible"

echo "All frontend smoke tests passed!"
