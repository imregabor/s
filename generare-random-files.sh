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
last_time="$START"
files_written=0
block_size=$(( 10 * 1024 * 1024 ))
min_block_size=$(( 32 * 1024 ))
block_count=10

# when set check free space, and set file size accordinglym otherwise adhere to bytes_to_write
fill_entire_disk=true
reserve_space=$(( 16 * 1024 ))


# bytes_to_write=0 # use 0 for no bound on data
# when fill_entire_disk is set then ignored
bytes_to_write=104857600
# bytes_to_write=1806080
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


trap 'echo; echo "Interrupted after completing $files_written files, $(human_readable_size "$TOTAL")."; exit 0' INT

while true ; do
  echo
  echo "[$(date)] Attempt to write next file"

  if [ "$fill_entire_disk" = true ] ; then
    echo
    echo "  Set file size based on free space"
    free_space=$(df -B1 . | awk 'NR==2 {print $4}')
    echo "    Free space: $(human_readable_size "$free_space")"
    if (( free_space > reserve_space )); then
      if (( single_file_size > free_space - reserve_space )); then
        block_size="$min_block_size"
        block_count=$(( (free_space - reserve_space) / block_size ))
        single_file_size=$(( block_size * block_count ))
        if (( block_count > 0 )); then
          echo "    Adjust file size to fit; write $block_count x $(human_readable_size $block_size) blocks"
          echo
        else
          echo "    No more blocks fit with minimal block size, exiting"
          echo
          break
        fi
      else
        echo "    No need to adjust file size"
        echo
      fi
    fi
  elif (( bytes_to_write > 0 && TOTAL + single_file_size > bytes_to_write )); then
    echo
    echo "  Already written $(human_readable_size "$TOTAL"), target $(human_readable_size "$bytes_to_write"), cannot write next file of $(human_readable_size "$single_file_size")"
    echo
    echo "    Adjust file size, using min block size $min_block_size ($(human_readable_size "$min_block_size"))"

    block_size="$min_block_size"
    block_count=$(( (bytes_to_write - TOTAL) / block_size ))
    single_file_size=$(( block_size * block_count ))

    if (( block_count > 0 )); then
      echo "  Attempt to write $block_count blocks"
      echo
    else
      echo "  No more blocks fit with minimal block size, exiting"
      echo
      break
    fi
  fi

  (( COUNT ++ )) || :

  FILENAME=$(printf '%04d.bin' $COUNT)

  CHECKSUMFILE="$FILENAME.sha1"


  if [ -e "$FILENAME" ]; then

    echo "  $FILENAME exists. Jump to next."
    continue
  fi

  echo "  Writing $(human_readable_size "$single_file_size") random file $((files_written + 1)) (in $(human_readable_size "$block_size") blocks) to $FILENAME"
  echo

  dd if=/dev/urandom "bs=$block_size" "count=$block_count" 2> >(sed -e 's/^/    /' >&2) | \
    tee "$FILENAME" | \
    sha1sum -b | \
    sed -e 's/-/\.\/'$FILENAME'/' >> ./all.sha1

  echo

  ((files_written ++)) || :

  last_bytes=$(stat -c %s "$FILENAME" 2>/dev/null)
  NOW=$(date +%s)
  TOTAL=$((TOTAL + last_bytes))
  ELAPSED=$((NOW - START))
  last_elapsed_time=$((NOW - last_time))
  last_time="$NOW"

  if (( last_elapsed_time > 0 )); then
   last_bps=$(( last_bytes / last_elapsed_time ))
  else
    last_bps="?"
  fi


  if [ "$ELAPSED" -eq 0 ]; then
    TP=""
  else
    TP=", throughput: $(human_readable_size "$((TOTAL / ELAPSED))")/s"
  fi

  echo "  Done writing file."
  echo "    Elapsed time:    $ELAPSED s"
  echo "    Last file write: $(human_readable_size "$last_bytes") in $last_elapsed_time s ($(human_readable_size "$last_bps")/s)"
  echo "    All writes:      $(human_readable_size "$TOTAL")$TP"
  echo
  echo



done
