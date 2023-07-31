#!/bin/bash

OF="./all.sha1"
OF_INPROGRESS="./all.sha1-inprogress"
FL="./all.filelist"
FL_DONE="./all.filelist-done"
FL_TODO="./all.filelist-todo"

if [ -e "$OF" ] && [ -e "$OF_INPROGRESS" ] ; then
  echo "ERROR! Both $OF and $OF_INPROGRESS exists; exiting"
  exit -1
fi

if [ -e "$OF" ] ; then
  echo "Rename $OF to $OF_INPROGRESS"
  mv "$OF" "$OF_INPROGRESS"
fi

if [ ! -f "$FL" ] ; then
  echo `date`" All file list file $FL is missing; generate"
  CT=0
  while read line ; do
    CT=$(( CT + 1 ))
    if [ $(( CT % 1000 )) == 0 ] ; then
      echo `date`" listed $CT files so far"
    fi
  done < <(find . -type f | grep -v "$OF" | grep -v "$OF_INPROGRESS" | grep -v "$FL_DONE" | grep -v "$FL_TODO" | tee "$FL")
  echo `date`" listing done; listed file count: $CT"
  echo `date`" start sort"
  sort -o "$FL" "$FL"
  echo `date`" sort done."
else
  echo `date`" Reuse already created file list $FL"
  echo `date`" line count: "$(wc -l < "$FL")
fi


if [ -f "$OF_INPROGRESS" ] ; then
  echo `date`" $OF_INPROGRESS exists; extract file names for already generated sums"
  echo `date`" already checksummed files: "$(wc -l < $OF_INPROGRESS)
  cat "$OF_INPROGRESS" | awk '{ print substr($0, 43) }' | sort > "$FL_DONE"
  comm -23 "$FL" "$FL_DONE" > "$FL_TODO"
else
  echo `date`" $OF / $OF_INPROGRESS missing, do checksum calculation on all listed files"
  touch "$FL_DONE"
  cp "$FL" "$FL_TODO"
fi

# see https://stackoverflow.com/questions/9458752/variable-for-number-of-lines-in-a-file
TODOS=$(wc -l < "$FL_TODO")

echo `date`" Start checksum calculation, total files to process: $TODOS"

CT=0

# see https://stackoverflow.com/questions/13726764/while-loop-subshell-dilemma-in-bash
while read line ; do

  sha1sum -b "$line" >> "$OF_INPROGRESS"
  CT=$(( CT + 1 ))
  if [ $(( CT % 100 )) == 0 ] || [ "$CT" -lt 100 ] ; then
    echo `date`" processed $CT (of $TODOS) files so far"
  fi

done < <(cat "$FL_TODO")

echo `date`" Finished checksum calculation; rename $OF_INPROGRESS to  $OF"
mv "$OF_INPROGRESS" "$OF"


rm "$FL_TODO"
rm "$FL_DONE"

echo `date`" All done; total file count: $CT."
