#!/bin/bash
#
# Calculate sha1 checksums for all files, write them into ./all.sha1
#
#

OF="./all.sha1"
OF_INPROGRESS="./all.sha1-inprogress"

if [ ! -z "$1" ] ; then
  OF=$(readlink -m "$OF")
  OF_INPROGRESS=$(readlink -m "$OF_INPROGRESS")
  echo "Will cd to \"$1\" for file listing"
  echo "  OF: \"$OF\""
  echo "  OF_INPROGRESS: \"$OF_INPROGRESS\""
  echo
  echo
  cd "$1"
fi

if [ -f "$OF_INPROGRESS" ] ; then
  echo "$OF_INPROGRESS exists; exiting."
  exit -1
fi

if [ -f "$OF" ] ; then
  echo "$OF exists; exiting."
  exit -1
fi

echo "Write checksums to intermediate file $OF_INPROGRESS"

CT=0

# see https://stackoverflow.com/questions/13726764/while-loop-subshell-dilemma-in-bash
while read line ; do
  sha1sum -b "$line" >> "$OF_INPROGRESS"
  CT=$(( CT + 1 ))
  if [ $(( CT % 100 )) == 0 ] || [ "$CT" -lt 100 ] ; then
    echo "  processed $CT files so far"
  fi
done < <(find . -type f | grep -v "$OF_INPROGRESS")

echo "  rename $OF_INPROGRESS to $OF"
mv "$OF_INPROGRESS" "$OF"

echo
echo
echo "All done; total file count: $CT."
echo
echo
