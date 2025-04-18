#!/bin/bash
#
# Generate random files with checksums
#
# Checksum is calculated on the fly without reading back the content.
#

# exit on error
set -e

if [ -e "./all.sha1" ]; then
  echo "ERROR! ./all.sha1 exists"
  exit 1
fi

COUNT=0
TOTAL=0
START=$(date +%s)

trap 'echo; echo "Interrupted after completing $((TOTAL / (1024*1024))) MB of writes."; exit 0' INT

while true ; do

  COUNT=$((COUNT + 1))
  FILENAME=$(printf '%04d.bin' $COUNT)
  echo "["$(date)"] Writing 100M random file $COUNT (in 10M blocks) to $FILENAME"
  echo

  dd if=/dev/urandom bs=$((10*1024*1024)) count=10 2> >(sed -e 's/^/    /' >&2) | \
    tee "$FILENAME" | \
    sha1sum -b | \
    sed -e 's/-/\.\/'$FILENAME'/' | \
    tee "$FILENAME.sha1" >> ./all.sha1

  echo

  NOW=$(date +%s)
  TOTAL=$((TOTAL + 100*1024*1024))
  ELAPSED=$((NOW - START))
  if [ "$ELAPSED" -eq 0 ]; then
    TP=""
  else
    TP=", throughput: $((TOTAL / (1024*1024*ELAPSED))) MB/s"
  fi

  echo "    Elapsed $ELAPSED secs$TP"
  echo
done
