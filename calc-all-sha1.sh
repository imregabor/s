#!/bin/bash
#
# Calculate sha1 checksums for all files, write them into ./all.sha1
#
#

echo
echo "================================================================="
echo
echo "Calc SHA1 checksums"
echo
echo "Launched in `pwd`"
echo
echo "================================================================="
echo

TFS=""
FCE=$(find -type f | head -10001 | wc -l)
if [ "$FCE" == "10001" ] ; then
  echo "  > 10000 files"
else
  TFS=$(du -h --apparent-size --summarize | cut -f 1)
  echo "  Total file count: $FCE"
  echo "  Total file sizes: $TFS"
fi

echo



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


echo "  Write checksums to intermediate file $OF_INPROGRESS"
echo

CT=0
T0=$(date +%s)

# see https://stackoverflow.com/questions/13726764/while-loop-subshell-dilemma-in-bash
while read line ; do
  sha1sum -b "$line" >> "$OF_INPROGRESS"
  CT=$(( CT + 1 ))
  if [ $(( CT % 100 )) == 0 ] || [ "$CT" -lt 100 ] ; then
    echo "  processed $CT files so far"
  fi
done < <(find . -type f | grep -v "$OF_INPROGRESS")

echo
echo "  rename $OF_INPROGRESS to $OF"
mv "$OF_INPROGRESS" "$OF"

T1=$(date +%s)
DT=$(($T1 - $T0))

echo
echo
echo "==========================================="
echo
echo "All done."
echo
if [ ! -z "$TFS" ] ; then
  echo "Total file sizes: $TFS"
fi
echo "Total file count: $CT"
echo "Total time:       $DT s"
echo
echo "==========================================="
echo
echo
