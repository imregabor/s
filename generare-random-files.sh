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

trap 'echo; echo "Interrupted after completing $((TOTAL / (1024*1024))) MiB of writes."; exit 0' INT

while true ; do

  COUNT=$((COUNT + 1))
  FILENAME=$(printf '%04d.bin' $COUNT)
  CHECKSUMFILE="$FILENAME.sha1"

  if [ -e "$FILENAME" ]; then
    echo "ERROR! $FILENAME exists"
    exit 1
  fi

  if [ -e "$CHECKSUMFILE" ]; then
    echo "ERROR! $CHECKSUMFILE exists"
    exit 1
  fi

  echo "["$(date)"] Writing 100 MiB random file $COUNT (in 10 MiB blocks) to $FILENAME, checksum to $CHECKSUMFILE"
  echo

  dd if=/dev/urandom bs=$((10*1024*1024)) count=10 2> >(sed -e 's/^/    /' >&2) | \
    tee "$FILENAME" | \
    sha1sum -b | \
    sed -e 's/-/\.\/'$FILENAME'/' | \
    tee "$CHECKSUMFILE" >> ./all.sha1

  echo

  NOW=$(date +%s)
  TOTAL=$((TOTAL + 100*1024*1024))
  ELAPSED=$((NOW - START))
  if [ "$ELAPSED" -eq 0 ]; then
    TP=""
  else
    TP=", throughput: $((TOTAL / (1024*1024*ELAPSED))) MiB/s"
  fi

  echo "    Elapsed $ELAPSED s, written $((TOTAL / (1024*1024))) MiB$TP"
  echo
done
