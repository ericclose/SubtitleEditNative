#!/bin/bash
set -e

# Subtitle Edit Native - Local Workflow Script
# Matches the logic used in GitHub Actions CI/CD Pipeline

echo "🚀 Starting Local Workflow..."

# Auto-detect .NET binary
if [ -z "$DOTNET_BIN" ]; then
    if command -v dotnet &> /dev/null; then
        DOTNET_BIN="dotnet"
    elif [ -f "$HOME/.dotnet/dotnet" ]; then
        DOTNET_BIN="$HOME/.dotnet/dotnet"
    else
        echo "❌ Error: 'dotnet' not found. Please install .NET 9."
        exit 1
    fi
fi

echo "--- 1. Running .NET Unit Tests ---"
"${DOTNET_BIN}" test LibSEBridge.Tests/LibSEBridge.Tests.csproj --configuration Release

echo "--- 2. Building .NET Bridge (Native AOT) ---"
"${DOTNET_BIN}" publish -c Release -r osx-arm64 --self-contained true /p:PublishAot=true /p:NativeLib=Shared -o bin/Native LibSEBridge/LibSEBridge.csproj

echo "--- 3. Distributing dylibs for Swift ---"
mkdir -p .build/debug
mkdir -p .build/release
cp bin/Native/*.dylib .build/debug/
cp bin/Native/*.dylib .build/release/
cp bin/Native/*.dylib .

echo "--- 4. Running Logic Stress Tests ---"
printf "1\n00:00:00,000 --> 00:00:05,000\nHello Stress Test\n\n" > dummy.srt
swift run TestRunner

echo "--- 5. Running Production Packaging ---"
chmod +x package.sh
./package.sh

echo "--- Workflow Complete ---"
echo "✅ Local verification passed. DMG generated."
