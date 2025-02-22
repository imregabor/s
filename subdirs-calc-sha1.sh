#!/bin/bash

# Find all directories from the current location recursively
find -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
    (cd "$dir" && "$(dirname "$0")/calc-all-sha1.sh")
done
