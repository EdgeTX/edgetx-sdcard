#!/bin/bash

generate_lang () {
  mkdir global/SOUNDS
  while read line
  do
      filename=`echo -n $line | awk -F ';' '{print $2}'`
      text=`echo -n $line | awk -F ';' '{print $3}'`
      mkdir -p global/SOUNDS/$3/SYSTEM/
      if test -f global/SOUNDS/$3/SYSTEM/$filename; then
          echo "File $filename already exists. Skipping."
      else
          echo "File $filename does not exists. Creating."
          spx synthesize --text \""$text"\" --voice $2 --audio output global/SOUNDS/$3/SYSTEM/$filename #&& sleep 10
      fi
  done < $1
}
