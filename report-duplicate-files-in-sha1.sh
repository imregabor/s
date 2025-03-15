#!/bin/bash
#
# Find duplicates based on checksums file
#


if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <checksum_file1> [checksum_file2]"
  exit 1
fi

checksum_file1="$1"
checksum_file2="$2"
checksum_file1_abs=$(readlink -m "$1")
checksum_file2_abs=$(readlink -m "$2")
checksum_file1_dir=$(dirname "$checksum_file1_abs")
checksum_file2_dir=$(dirname "$checksum_file2_abs")


if [ ! -f "$checksum_file1" ]; then
  echo "Error: File 1 '$checksum_file1' not found."
  exit 1
fi

if [ ! -z "$checksum_file2" ]; then
  if [ ! -f "$checksum_file2" ]; then
    echo "Error: File 2 '$checksum_file2' not found."
    exit 1
  fi
fi



OD="./checksum-duplicate-report-$(date -u +%Y%m%d-%H%M%S)"
LOGFILE="$OD/report.log"
echo "Output directory: $OD"
echo "Logfile:          $LOGFILE"

mkdir -p "$OD"
log() {
  echo "$1" | tee -a "$LOGFILE"
}


log
log "================================================================"
log
log "Checksum 1:    $checksum_file1"
log "               $checksum_file1_abs"
log "File 1 count: "$(cat "$checksum_file1" | wc -l)
log 
if [ ! -z "$checksum_file2" ]; then
  log "Checksum 2:    $checksum_file2"
  log "               $checksum_file2_abs"
  log "File 2 count: "$(cat "$checksum_file2" | wc -l)
  log
fi
log "================================================================"
log

if [ -z "$checksum_file2" ]; then
  FILTERED_CHECKSUMS="$OD/filtered-checksums"
  log "Looking for duplicate checksums, write results to $FILTERED_CHECKSUMS"

  awk '{print $1}' "$checksum_file1" | sort | uniq -d > "$FILTERED_CHECKSUMS"
  DUPLICATE_COUNT=$(cat "$FILTERED_CHECKSUMS" | wc -l)

  log "  Done, duplicate checksum instances: $DUPLICATE_COUNT"
  log

  I=0

  # Single file mode: Find duplicates within the file
  cat "$FILTERED_CHECKSUMS" | while read checksum; do
    I=$(( I + 1 ))
    log "Duplicate checksum $I of $DUPLICATE_COUNT: $checksum"
    dupes=$(grep "^$checksum" "$checksum_file1")
    log "$dupes"
    log
  done
else
  FILTERED_CHECKSUMS="$OD/filtered-checksums"
  log "Looking for duplicate checksums, write results to $FILTERED_CHECKSUMS"
  comm -12 <(awk '{print $1}' "$checksum_file1" | sort | uniq) <(awk '{print $1}' "$checksum_file2" | sort | uniq) > "$FILTERED_CHECKSUMS"
  DUPLICATE_COUNT=$(cat "$FILTERED_CHECKSUMS" | wc -l)
  

  log "  Done, duplicate checksum instances: $DUPLICATE_COUNT"
  log
  

  I=0

  # Two file mode: Compare checksums between both files
  cat "$FILTERED_CHECKSUMS" | while read checksum; do
    I=$(( I + 1 ))
    log "Matching checksum $I of $DUPLICATE_COUNT in both files: $checksum"
    log "  [$checksum_file1]"
    dupes1=$(grep "^$checksum" "$checksum_file1" | sed -e 's/^/    /')
    log "$dupes1"
    log "  [$checksum_file2]"
    dupes2=$(grep "^$checksum" "$checksum_file2" | sed -e 's/^/    /')
    log "$dupes2"
    log
  done
fi


log
log "All done."
