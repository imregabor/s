#!/bin/bash

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <sha1sum_file1> [sha1sum_file2]"
  exit 1
fi

sha1sum_file1="$1"
sha1sum_file2="$2"

if [ ! -f "$sha1sum_file1" ]; then
  echo "Error: File '$sha1sum_file1' not found."
  exit 1
fi

if [ -z "$sha1sum_file2" ]; then
  # Single file mode: Find duplicates within the file
  awk '{print $1}' "$sha1sum_file1" | sort | uniq -d | while read checksum; do
    echo "Duplicate checksum: $checksum"
    grep "^$checksum" "$sha1sum_file1"
    echo
  done
else
  if [ ! -f "$sha1sum_file2" ]; then
    echo "Error: File '$sha1sum_file2' not found."
    exit 1
  fi

  # Two file mode: Compare checksums between both files
  comm -12 <(awk '{print $1}' "$sha1sum_file1" | sort | uniq) <(awk '{print $1}' "$sha1sum_file2" | sort | uniq) | while read checksum; do
    echo "Matching checksum in both files: $checksum"
    echo "  [$sha1sum_file1]"
    grep "^$checksum" "$sha1sum_file1" | sed -e 's/^/    /'
    echo "  [$sha1sum_file2]"
    grep "^$checksum" "$sha1sum_file2" | sed -e 's/^/    /'
    echo
  done
fi
