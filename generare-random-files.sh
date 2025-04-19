#!/bin/bash
#
# Generate random files with checksums
#
# Checksum is calculated on the fly without reading back the content.
#

# exit on error
set -e

if [ -e "./all.sha1" ]; then
  echo "WARNING! ./all.sha1 exists, will not overwrite existing binary files"
fi

COUNT=0
TOTAL=0
START=$(date +%s)
files_written=0
block_size=$(( 1024 * 1024 * 10 ))
block_count=1
bytes_to_write=0
single_file_size=$(( block_size * block_count ))

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


trap 'echo; echo "Interrupted after completing $(files_written) files, $(human_readable_size "$TOTAL")."; exit 0' INT


while true ; do

  if (( bytes_to_write > 0 && TOTAL + single_file_size > bytes_to_write )); then
    echo
    echo "Already written $(human_readable_size "$TOTAL"), target $(human_readable_size "$bytes_to_write"), cannot write next file of $(human_readable_size "$single_file_size")"
    break
  fi

  (( COUNT ++ )) || :

  FILENAME=$(printf '%04d.bin' $COUNT)

  CHECKSUMFILE="$FILENAME.sha1"


  if [ -e "$FILENAME" ]; then

    echo "WARNING! $FILENAME exists. Jump to next."
    continue
  fi

  if [ -e "$CHECKSUMFILE" ]; then
    echo "WARNING! $CHECKSUMFILE exists. Jump to next."
    exit 1
  fi

  echo "["$(date)"] Writing $(human_readable_size "$single_file_size") random file $((files_written + 1)) (in $(human_readable_size "$block_size") blocks) to $FILENAME, checksum to $CHECKSUMFILE"
  echo

  dd if=/dev/urandom "bs=$block_size" "count=$block_count" 2> >(sed -e 's/^/    /' >&2) | \
    tee "$FILENAME" | \
    sha1sum -b | \
    sed -e 's/-/\.\/'$FILENAME'/' | \
    tee "$CHECKSUMFILE" >> ./all.sha1

  echo

  ((files_written ++)) || :

  last_bytes=$(stat -c %s "$FILENAME" 2>/dev/null)
  NOW=$(date +%s)
  TOTAL=$((TOTAL + last_bytes))
  ELAPSED=$((NOW - START))
  if [ "$ELAPSED" -eq 0 ]; then
    TP=""
  else
    TP=", throughput: $(human_readable_size "$((TOTAL / ELAPSED))")/s"
  fi

  echo "    Elapsed $ELAPSED s, written $(human_readable_size $"last_bytes"), total $(human_readable_size "$TOTAL")$TP"
  echo



done
