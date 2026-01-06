#!/bin/bash

echo
echo
echo "Verify the presence of checksum file in first level subdirectories"
echo
echo

MISSING_COUNT=0
IN_PROGRESS_COUNT=0
OK_COUNT=0
TOTAL_MISSING_BYTES=0

HASMISSING=false
while read line ; do
  STAT="?"
  if [ -f "${line}/all.sha1" ] ; then
    STAT="OK           "
    ((OK_COUNT++))
  elif [ -f "${line}/all.sha1-inprogress" ] ; then
    STAT="IN PROGRESS  "
    ((IN_PROGRESS_COUNT++))
  else
    STAT="** MISSING **"
    HASMISSING=true
    ((MISSING_COUNT++))
  fi
  echo "$STAT $line"
done < <( find -maxdepth 1 -mindepth 1 -type d)

if "$HASMISSING" ; then
    echo
    echo "Size of unchecked directories"
    echo

    while read line ; do
      if [ -f "${line}/all.sha1" ] || [ -f "${line}/all.sha1-inprogress" ]; then
        continue
      fi
      echo "$line:"
      echo "  "$(du -hs "$line")
      echo
      BYTES=$(du -sb "$line" | cut -f1)
      ((TOTAL_MISSING_BYTES+=BYTES))
    done < <( find -maxdepth 1 -mindepth 1 -type d)
fi

human_readable_size() {
  local size="$1"

  if [[ "$size" == "?" ]]; then
    echo "? B"
    return
  fi

  local -a suffixes=("B" "KiB" "MiB" "GiB" "TiB" "PiB")
  local i=0
  local float_size="$size"
  local rounded_size="$size"

  while (( rounded_size >= 1024 && i < ${#suffixes[@]} - 1 )); do
    float_size=$(awk "BEGIN {printf \"%.2f\", $float_size/1024}")
    rounded_size=$(( rounded_size / 1024 ))
    ((i++))
  done

  echo "$float_size ${suffixes[i]}"
}

echo
echo
echo "Stats:"
echo
echo "  OK:          $OK_COUNT"
echo "  MISSING:     $MISSING_COUNT"
echo "  IN_PROGRESS: $IN_PROGRESS_COUNT"
echo
echo "  TOTAL SIZE:  $(human_readable_size $TOTAL_MISSING_BYTES) ($TOTAL_MISSING_BYTES B)"
echo
echo
echo "all done."
echo
