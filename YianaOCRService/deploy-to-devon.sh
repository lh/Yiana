#!/bin/bash

# Deploy YianaOCRService to Mac Mini (Devon)
# Usage: ./deploy-to-devon.sh

set -e  # Exit on error

DEVON_HOST="192.168.1.137"
DEVON_USER="devon"
DEVON_BIN_PATH="/Users/devon/bin/yiana-ocr"
BUILD_DIR=".build/arm64-apple-macosx/release"
BINARY_NAME="yiana-ocr"

echo "🔨 Building YianaOCRService in release mode..."
swift build -c release

echo ""
echo "📦 Binary built: ${BUILD_DIR}/${BINARY_NAME}"
ls -lh "${BUILD_DIR}/${BINARY_NAME}"

echo ""
echo "🚀 Deploying to Devon (${DEVON_HOST})..."
echo "   Target: ${DEVON_USER}@${DEVON_HOST}:${DEVON_BIN_PATH}"

# Stop the service and wait for launchd to restart it (with old binary)
echo ""
echo "🛑 Stopping yiana-ocr on Devon..."
ssh "${DEVON_USER}@${DEVON_HOST}" "pkill -x yiana-ocr || true"
sleep 2

# Kill the launchd-respawned process so it doesn't hold the old binary
ssh "${DEVON_USER}@${DEVON_HOST}" "pkill -x yiana-ocr || true"

# Backup existing binary
echo ""
echo "💾 Backing up existing binary..."
ssh "${DEVON_USER}@${DEVON_HOST}" "if [ -f ${DEVON_BIN_PATH} ]; then cp ${DEVON_BIN_PATH} ${DEVON_BIN_PATH}.backup.\$(date +%Y%m%d-%H%M%S); fi"

# Copy new binary
echo ""
echo "📤 Copying new binary to Devon..."
scp "${BUILD_DIR}/${BINARY_NAME}" "${DEVON_USER}@${DEVON_HOST}:${DEVON_BIN_PATH}"

# Set executable permissions
echo ""
echo "🔐 Setting executable permissions..."
ssh "${DEVON_USER}@${DEVON_HOST}" "chmod +x ${DEVON_BIN_PATH}"

# Kill whatever launchd respawned so it picks up the new binary
echo ""
echo "🔄 Restarting service with new binary..."
ssh "${DEVON_USER}@${DEVON_HOST}" "pkill -x yiana-ocr || true"
sleep 3

# Verify deployment
echo ""
echo "✅ Verifying deployment..."
ssh "${DEVON_USER}@${DEVON_HOST}" "ls -lh ${DEVON_BIN_PATH} && pgrep -lf yiana-ocr"

echo ""
echo "🎉 Deployment complete! Service is running with new binary."
echo ""
echo "To restore previous version if needed:"
echo "   ssh ${DEVON_USER}@${DEVON_HOST}"
echo "   cp ${DEVON_BIN_PATH}.backup.* ${DEVON_BIN_PATH}"
