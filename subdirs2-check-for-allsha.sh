#!/bin/bash

echo
echo
echo "Verify the presence of checksum file in second level subdirectories"
echo
echo

HASMISSING=false
while read line ; do
  STAT="?"
  if [ -f "${line}/all.sha1" ] ; then
    STAT="OK           "
  elif [ -f "${line}/all.sha1-inprogress" ] ; then
    STAT="IN PROGRESS  "
  else
    STAT="** MISSING **"
    HASMISSING=true
  fi
  echo "$STAT $line"
done < <( find -maxdepth 2 -mindepth 2 -type d)

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
    done < <( find -maxdepth 2 -mindepth 2 -type d)
fi

echo
echo "all done."
echo
