#!/bin/bash
# Build the YianaTypstBridge XCFramework for all Apple targets.
#
# Prerequisites:
#   rustup target add aarch64-apple-darwin x86_64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim
#   cargo install cbindgen
#
# Usage:
#   ./build-xcframework.sh

set -euo pipefail

cd "$(dirname "$0")"

echo "Building for macOS (ARM64)..."
cargo build --release --target aarch64-apple-darwin

echo "Building for macOS (x86_64)..."
cargo build --release --target x86_64-apple-darwin

echo "Building for iOS (ARM64)..."
cargo build --release --target aarch64-apple-ios

echo "Building for iOS Simulator (ARM64)..."
cargo build --release --target aarch64-apple-ios-sim

echo "Generating C header..."
mkdir -p include
cbindgen --config cbindgen.toml --crate yiana-typst-bridge --output include/yiana_typst_bridge.h

echo "Creating XCFramework..."
rm -rf YianaTypstBridge.xcframework

xcodebuild -create-xcframework \
  -library target/aarch64-apple-darwin/release/libyiana_typst_bridge.a -headers include/ \
  -library target/aarch64-apple-ios/release/libyiana_typst_bridge.a -headers include/ \
  -library target/aarch64-apple-ios-sim/release/libyiana_typst_bridge.a -headers include/ \
  -output YianaTypstBridge.xcframework

echo "Done. XCFramework at: YianaTypstBridge.xcframework"
ls -lh YianaTypstBridge.xcframework/*/libyiana_typst_bridge.a
