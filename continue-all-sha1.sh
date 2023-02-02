#!/bin/bash

OF="./all.sha1"
OF_INPROGRESS="./all.sha1-inprogress"
FL="./all.filelist"
FL_DONE="./all.filelist-done"
FL_TODO="./all.filelist-todo"

if [ -e "$OF" ] && [ -e "$OF_INPROGRESS" ] ; then
  echo "Both $OF and $OF_INPROGRESS exists; exiting"
  exit -1
fi

if [ -e "$OF" ] ; then
  echo "Rename $OF to $OF_INPROGRESS"
  mv "$OF" "$OF_INPROGRESS"
fi

if [ ! -f "$FL" ] ; then
  echo "$FL is missing; generate"
  CT=0
  while read line ; do
    CT=$(( CT + 1 ))
    if [ $(( CT % 1000 )) == 0 ] ; then
      echo "  listed $CT files so far"
    fi
  done < <(find . -type f | grep -v "$OF" | grep -v "$OF_INPROGRESS" | grep -v "$FL_DONE" | grep -v "$FL_TODO" | tee "$FL")
  echo "  listing done; listed file count: $CT."
  echo "  start sort"
  sort -o "$FL" "$FL"
  echo "  sort done."
else
  echo "Reuse already created file list $FL"
  echo "  line count: "$(wc -l "$FL")
fi


if [ -f "$OF_INPROGRESS" ] ; then
  echo "$OF_INPROGRESS exists; extract file names for already generated sums"
  echo "  already checksummed files: "$(wc -l $OF_INPROGRESS)
  cat "$OF_INPROGRESS" | awk '{ print substr($0, 43) }' | sort > "$FL_DONE"
  comm -23 "$FL" "$FL_DONE" > "$FL_TODO"
else
  echo "$OF / $OF_INPROGRESS missing, do checksum calculation on all listed files"
  touch "$FL_DONE"
  cp "$FL" "$FL_TODO"
fi

echo "Start checksum calculation, total files to process "$(wc -l "$FL_TODO")

CT=0

# see https://stackoverflow.com/questions/13726764/while-loop-subshell-dilemma-in-bash
while read line ; do

  sha1sum -b "$line" >> "$OF_INPROGRESS"
  CT=$(( CT + 1 ))
  if [ $(( CT % 100 )) == 0 ] ; then
    echo "processed $CT files so far"
  fi

done < <(cat "$FL_TODO")

mv "$OF_INPROGRESS" "$OF"
rm "$FL_TODO"
rm "$FL_DONE"

echo "All done; total file count: $CT."