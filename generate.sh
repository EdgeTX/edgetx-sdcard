#!/bin/bash

set -euo pipefail

# Check prerequisites
error_msg() {
    if [ -z "${GITHUB_ACTIONS:-}" ]; then
        echo "❌ Error: $1" >&2
    else
        echo "::error::$1"
    fi
}

if [ ! -d "sdcard" ]; then
    error_msg "sdcard directory not found"
    exit 1
fi

if [ ! -d "sdcard/global" ]; then
    error_msg "sdcard/global directory not found"
    exit 1
fi

if [ ! -f "sdcard.json" ]; then
    error_msg "sdcard.json not found"
    exit 1
fi

# Extract unique variants from sdcard.json and validate they exist
echo "Validating variants..."
variants=$(grep -oE '"(bw[0-9]+x[0-9]+|c[0-9]+x[0-9]+)"' sdcard.json | tr -d '"' | sort -u)
missing_variants=()

for variant in $variants; do
    if [ ! -d "sdcard/$variant" ]; then
        missing_variants+=("$variant")
    fi
done

if [ ${#missing_variants[@]} -gt 0 ]; then
    error_msg "Missing variant directories:"
    for variant in "${missing_variants[@]}"; do
        if [ -z "${GITHUB_ACTIONS:-}" ]; then
            echo "  - sdcard/$variant" >&2
        else
            echo "::error::  sdcard/$variant"
        fi
    done
    exit 1
fi

# Create distribution directory
rm -rf dist sdcard-build
mkdir -p dist sdcard-build

echo "Building distribution (dereferencing symlinks)..."
rsync -rL sdcard/ sdcard-build/

# Get absolute path to dist for use in subshells
dist_path="$(cd dist && pwd)"

# Copy generic variant content
for dir in sdcard-build/*/; do
    dir_name=$(basename "$dir")

    # Determine variant, copy content only if it doesn't exist
    if [[ "$dir_name" == bw* && "$dir_name" != "bw" ]]; then
        [ -d "sdcard-build/bw" ] && rsync -r --ignore-existing sdcard-build/bw/ "$dir"
    elif [[ "$dir_name" == c* && "$dir_name" != "color" ]]; then
        [ -d "sdcard-build/color" ] && rsync -r --ignore-existing sdcard-build/color/ "$dir"
    fi
done

# Copy global content into each variant
for dir in sdcard-build/*/; do
    dir_name=$(basename "$dir")
    if [ "$dir_name" != "bw" ] && [ "$dir_name" != "color" ] && [ "$dir_name" != "global" ]; then
        rsync -r sdcard-build/global/ "$dir"
    fi
done

# Zip only the specific variants
echo "Creating distribution packages..."
for dir in sdcard-build/*/; do
    dir_name=$(basename "$dir")
    if [ "$dir_name" != "bw" ] && [ "$dir_name" != "color" ] && [ "$dir_name" != "global" ]; then
        echo "  Building $dir_name.zip..."
        (cd "$dir" && zip -qr "$dist_path/$dir_name.zip" *)
    fi
done

# Cleanup (skip in GitHub Actions)
if [ -z "${GITHUB_ACTIONS:-}" ]; then
    rm -r sdcard-build
fi

echo ""
echo "Generated Packages:"
ls -lh dist/*.zip 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
