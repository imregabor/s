#!/bin/bash
#
# Identify some redundant all.sha1 coverage
#
# Note that actual contents will not be checked just file locations.
# This script does not write/modify storage.

find -type f -wholename '*/all.sha1' \
  | sed -e 's|all\.sha1$||' \
  | sort \
  | awk '
    BEGIN { prev="//////" }
    {
      if (index($0, prev)) {
        print prev "\t" $0
      }
      prev = $0 ;
    }'
