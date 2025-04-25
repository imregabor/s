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



OF=$(readlink -m "./all.sha1")
OF_INPROGRESS=$(readlink -m "./all.sha1-inprogress")

if [ ! -z "$1" ] ; then
  OF=$(readlink -m "$OF")
  OF_INPROGRESS=$(readlink -m "$OF_INPROGRESS")
  echo "Will cd to \"$1\" for file listing (write all.sha1 in original wd)"
  echo "  OF:            \"$OF\""
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

echo "  Estimate file count"

TFSB=""
TFS=""
FCE=$(timeout 20 bash -c "find -type f | head -500001 | wc -l")
FCE_STATUS=$?

TFL=""
if [ "$FCE_STATUS" != "0" ] ; then
  echo "  Cannot estimate file count in 20 s, exit status of du find: $FCE_STATUS"
elif [ "$FCE" == "500001" ] ; then
  echo "  > 500k files, skip counting files and used space"
else
  TFL=" (of $FCE)"
  echo "  Total file count: $FCE"
  echo

  echo "  Estimate total file sizes"
  DU_OUT=$(timeout 20 du -b --apparent-size --summarize)
  DU_STATUS=$?

  if [ "$DU_STATUS" == "0" ] ; then
    TFSB=$(echo "$DU_OUT" | cut -f 1)
    TFS=$(human_readable_size "$TFSB")
    echo "  Total file sizes: $TFS"
  else
    echo "  Cannot calculate total file sizes in 20 s; exit status of timeout du: $DU_STATUS"
  fi
fi

echo



echo "  Write checksums to intermediate file $OF_INPROGRESS"
echo

CT=0
T0=$(date +%s)

# see https://stackoverflow.com/questions/13726764/while-loop-subshell-dilemma-in-bash
while read line ; do
  sha1sum -b "$line" >> "$OF_INPROGRESS"
  CT=$(( CT + 1 ))
  if [ $(( CT % 100 )) == 0 ] || [ "$CT" -lt 100 ] ; then
    echo "  processed $CT$TFL files so far (last file: $line)"
  fi
done < <(find . -type f | grep -av "$OF_INPROGRESS")


if (( CT > 0 )); then
  echo
  echo "  rename $OF_INPROGRESS to $OF"
  mv "$OF_INPROGRESS" "$OF"
else
  echo "  No files found"
fi

T1=$(date +%s)
DT=$(($T1 - $T0))

echo
echo
echo "==========================================="
echo
echo "All done."
echo
if [[ "$TFS" != "" ]] ; then
  echo "Total file sizes: $TFS"
fi
echo "Total file count: $CT"
echo "Total time:       $DT s"

if [[ "$DT" -gt 0 && "$TFS" != "" ]]; then
  echo "Throughput:       $(human_readable_size $(( TFSB / DT ))) / s"
fi

echo
echo "==========================================="
echo
echo
