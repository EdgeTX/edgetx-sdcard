#!/bin/bash

mkdir dist
cp index.json dist/
cp -r sdcard sdcard-build

for dir in sdcard-build/*/; do
    cp -r global/* "$dir/"
done

cd sdcard-build || exit

for d in * ; do
    cd "$d" || exit
    zip -r "../../dist/$d.zip" ./*
    cd .. || exit
done
cd .. || exit

rm -r sdcard-build
