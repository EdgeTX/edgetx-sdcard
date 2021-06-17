#!/bin/bash

# include voice generator script
. $(dirname "$0")/voice-gen.sh

spx config @key --set $AZURE_KEY
spx config @region --set $AZURE_REGION

mkdir dist
cp index.json dist/
cp -r sdcard sdcard-build

generate_lang voices/en-US-taranis.csv en-IE-EmilyNeural en
# generate_lang voices/pt-PT-taranis.csv pt-BR-FranciscaNeural pt
# generate_lang voices/es-ES-taranis.csv es-ES-ElviraNeural es
# generate_lang voices/it-IT-taranis.csv it-IT-ElsaNeural it
# generate_lang voices/de-DE-taranis.csv de-DE-KatjaNeural de
# generate_lang voices/fr-FR-taranis.csv fr-FR-DeniseNeural fr
# generate_lang voices/ru-RU-taranis.csv ru-RU-SvetlanaNeural ru
# generate_lang voices/cs-CZ-taranis.csv cs-CZ-VlastaNeural cz

for dir in sdcard-build/*/; do cp -r global/* "$dir/"; done

cd sdcard-build
for d in * ; do
    zip -r ../dist/$d.zip $d/*
done
cd ..

rm -r sdcard-build
