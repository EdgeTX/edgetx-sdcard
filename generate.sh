#!/bin/bash

for dir in sdcard/*/; do mkdir -- "$dir/SOUNDS"; done

mkdir -p dist/sdcard
cp -r sounds/* sdcard/*/SOUNDS/
cp index.json dist/
cp CNAME dist/

for d in sdcard/* ; do
    zip -r dist/$d.zip $d
done

for dir in sdcard/*/; do rm -rf -- "$dir/SOUNDS"; done