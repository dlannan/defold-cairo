#!/bin/bash

# Make sure you have inkscape installed tp run this.
for file in *.svg
    do
        inkscape -z -w 64 -h 64 "$file" -e "${file%.*}.png"
    done
