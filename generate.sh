#!/bin/bash

cp index.json dist/
mkdir dist

for dir in sdcard/*/; do mkdir -- "$dir/SOUNDS"; done
for dir in sdcard/*/; do cp -r sounds/* "$dir/SOUNDS/"; done

cd sdcard
for d in * ; do
    zip -r ../dist/$d.zip $d/*
done
cd ..

for dir in sdcard/*/; do rm -rf -- "$dir/SOUNDS"; done