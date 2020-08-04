#!/bin/bash

# Root img 
for file in ./*.jpg ./*.png ./*/*/*.jpg ./*/*/*.png
do
  if [ ! -f $file.bak ]
  then
    cp $file $file.bak
    cwebp $file -o "$file"
  fi
done
