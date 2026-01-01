#!/bin/bash

set -euo pipefail

# Check prerequisites
if [ ! -d "sdcard" ]; then
    echo "::error::sdcard directory not found"
    exit 1
fi

if [ ! -d "global" ]; then
    echo "::error::global directory not found"
    exit 1
fi

# Create distribution directory
rm -rf dist
mkdir -p dist
cp -r sdcard sdcard-build

# Copy generic variant content
for dir in sdcard-build/*/; do
    dir_name=$(basename "$dir")
    
    # Determine variant, copy content only if it doesn't exist
    if [[ "$dir_name" == bw* && "$dir_name" != "bw" ]]; then
        [ -d "sdcard-build/bw" ] && rsync --ignore-existing sdcard-build/bw/ "$dir"
    elif [[ "$dir_name" == c* && "$dir_name" != "color" ]]; then
        [ -d "sdcard-build/color" ] && rsync --ignore-existing sdcard-build/color/ "$dir"
    fi
done

# Copy global content into each variant
for dir in sdcard-build/*/; do
    dir_name=$(basename "$dir")
    if [ "$dir_name" != "bw" ] && [ "$dir_name" != "color" ]; then
        cp -r global/* "$dir"
    fi
done

# Zip only the specific variants
echo "Creating distribution packages..."
for dir in sdcard-build/*/; do
    dir_name=$(basename "$dir")
    if [ "$dir_name" != "bw" ] && [ "$dir_name" != "color" ]; then
        echo "  Building $dir_name.zip..."
        zip -qr "dist/$dir_name.zip" "$dir"*
    fi
done

# Cleanup (skip in GitHub Actions)
if [ -z "${GITHUB_ACTIONS:-}" ]; then
    rm -r sdcard-build
fi

echo "✓ Build complete"
