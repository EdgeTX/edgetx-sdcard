#!/bin/bash

generate_lang () {
  while read line
  do
      filename=`echo -n $line | awk -F ';' '{print $2}'`
      text=`echo -n $line | awk -F ';' '{print $3}'`
      if test -f $voice/$filename; then
          echo "File $filename already exists. Skipping."
      else
          echo "File $filename does not exists. Creating."
          spx synthesize --text \""$text"\" --voice $2 --audio output global/$filename && sleep 10
      fi
  done < $1
}