#!/bin/bash

# include voice generator script
. $(dirname "$0")/voice-gen.sh

mkdir dist
cp index.json dist/
cp -r sdcard sdcard-build

for dir in sdcard-build/*/; do mkdir -- "$dir/SOUNDS"; done
for dir in sdcard-build/*/; do cp -r global/* "$dir/"; done

cd sdcard-build
for d in * ; do
    zip -r ../dist/$d.zip $d/*
done
cd ..

rm -r sdcard-build