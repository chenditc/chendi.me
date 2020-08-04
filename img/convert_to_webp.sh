#!/bin/bash
for file in ./*.jpg
do
  cp $file $file.bak
  cwebp $file -o "${file%.*}.jpg"
done
