#!/bin/bash

mkdir dist
cp index.json dist/
cp -r sdcard sdcard-build

for dir in sdcard-build/*/; do cp -r global/* "$dir/"; done

cd sdcard-build
for d in * ; do
    zip -r ../dist/$d.zip $d/*
done
cd ..

rm -r sdcard-build
