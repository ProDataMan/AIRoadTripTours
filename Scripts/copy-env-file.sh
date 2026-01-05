#!/bin/bash

# Copy .env file to app bundle if it exists
# This script should be run as a build phase in Xcode

ENV_FILE="${PROJECT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
    echo "✅ Found .env file, copying to app bundle..."
    cp "$ENV_FILE" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/.env"
    echo "✅ .env file copied successfully"
else
    echo "⚠️ No .env file found at ${ENV_FILE}"
    echo "   Create one from .env.example if needed"
fi
