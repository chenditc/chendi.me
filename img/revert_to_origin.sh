#!/bin/bash

# Root img 
for file in ./*.jpg ./*.png ./*/*/*.jpg ./*/*/*.png
do
  if [ -f $file.bak ]
  then
    mv $file.bak $file
  fi
done
