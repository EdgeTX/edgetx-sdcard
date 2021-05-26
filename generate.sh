#!/bin/bash

mkdir sdcard/*/SOUNDS dist
cp -r sounds/* sdcard/*/SOUNDS/
cp sdcard/index.json dist/

for d in sdcard/*/ ; do
    zip -r dist/$d.zip sdcard/$d
done
