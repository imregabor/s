#!/bin/bash

# Find two levels subdirectories from the current location recursively
find -maxdepth 2 -mindepth 2 -type d | while read -r dir; do
    (cd "$dir" && "$(dirname "$0")/calc-all-sha1.sh")
done
