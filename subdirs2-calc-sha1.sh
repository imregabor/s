#!/bin/bash
#
# Find all second level child directories from the current location
# and invoke sha1 calculation in all of them.
#
# Note that existing all.sha1 (or all.sha1-inprogress) wont be touched
#

find -maxdepth 2 -mindepth 2 -type d | while read -r dir; do
    (cd "$dir" && "$(dirname "$0")/calc-all-sha1.sh")
done
