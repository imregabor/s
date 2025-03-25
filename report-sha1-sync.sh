#!/bin/bash
#
# Report sync between FS and "all.sha1" checksum files
#

if ! command -v readlink &> /dev/null; then
  echo "Error: readlink is not available."
  exit 1
fi

usage() {
  echo
  echo "Check/report/fix sync between FS and checksum file(s)"
  echo
  echo "Usage:"
  echo
  echo "  $0 [-h] [-f] <TARGET_PATH>"
  echo
  echo "<TARGET_PATH> Target location:"
  echo
  echo "  If points to a checksum file it will be checked."
  echo
  echo "  If points to a directory it will be searched for \"all.sha\" files,"
  echo "  all hits will be processed."
  echo
  echo "Options:"
  echo "  -h, --help     Print this help and exit."
  echo "  -f, --fix      Fix checksum file(s) in case of discrepancy."
  echo
  exit 1
}

# Default values
FIX_MODE=false
TARGET=""

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -f|--fix)
      FIX_MODE=true
      shift
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$1"
      else
        echo "Error: Multiple targets provided."
        echo
        usage
      fi
      shift
      ;;
  esac
done

# Ensure target is provided
if [[ -z "$TARGET" ]]; then
  echo "Error: No target file or directory specified."
  echo
  usage
fi

# Ensure target is provided
if [[ ! -e "$TARGET" ]]; then
  echo "Target file/dir not found: $TARGET"
  echo
  usage
fi

# Output dir for report
OD=$(readlink -m "./sha1-checksum-consistency-report-$(date -u +%Y%m%d-%H%M%S)")
LOGFILE="$OD/report.log"
mkdir -p "$OD" || { echo "Error: Failed to create output report directory '$OD'." >&2; exit 1; }

log() {
  echo "$@" | tee -a "$LOGFILE"
}


# Visited checksum file count
CT=0
# All checksum file count
ALLCT=0

# All checksum files encountered
ALLCHECKSUMFILES="$OD/all-checksum-files.txt"

visit() {
  local CHECKSUMFILE
  CHECKSUMFILE=$1

  CT=$((CT + 1))
  RD="$OD/report-"$(printf "%04d" "$CT")
  CD=$(dirname "$CHECKSUMFILE")
  CD=$(readlink -m "$CD")
  FL="$RD/file-list.txt"
  OCF="$RD/"$(basename "$CHECKSUMFILE")"-original"
  OCFFL="$RD/file-list-from-original-checksum-file.txt"
  NFL="$RD/new-file-list.txt"
  RFL="$RD/removed-file-list.txt"
  NCF="$RD/"$(basename "$CHECKSUMFILE")"-new"

  log "=============================================================================================================="
  log "="
  log "= Processing checksum file $CT of $ALLCT: $CHECKSUMFILE"
  log "="
  log "= Individual report dir:           $RD"
  log "="
  log "= Checksum dir:                    $CD"
  log "= Absolute checksum file:          $SRCDIR/$CHECKSUMFILE"
  log "="
  log "= File list:                       $FL"
  log "= Original checksum file archive:  $OCF"
  log "= Original checksum file lists:    $OCFFL"
  log "= New file list:                   $NFL"
  log "= Removed file list:               $RFL"
  if [ "$CHANGE" = true ]; then
    log "= New checksum file:               $NCF"
  fi
  log "="
  log "=============================================================================================================="
  log

  mkdir -p "$RD"
  echo "$CD" > "$RD/pwd.txt"

  log "  Archive original checksum file to $OCF"
  cp "$CHECKSUMFILE" "$OCF"
  log "    file count in original checksum file: "$(wc -l < "$OCF")

  log "  Extract original checksum file list"
  cat "$CHECKSUMFILE" | sed -e 's/^[^ ]* .\(.*\)/\1/' | sort -u > "$OCFFL"
  log "    unique file count listed:             "$(wc -l < "$OCFFL")

  log "  List files"

  cd "$CD"
  find -type f ! -name "all.sha1" ! -name "all.sha1-backup-*" | sort -u > "$FL"
  log "    files found:                          "$(wc -l < "$OCFFL")

  log "  Calculate new / removed file lists"

  comm -23 "$FL" "$OCFFL" > "$NFL"
  comm -13 "$FL" "$OCFFL" > "$RFL"

  CHANGE="false"

  log
  if [ "$FIX_MODE" = "true" ]; then
    # Fixing
    if [ -s "$RFL" ] ; then
      log "  Remove missing files from checksum. Removed file count: "$(wc -l < "$RFL")

      awk 'NR==FNR {
          remove[$0] = "x"
          next
        }
        {
          pos1 = index($0, "  ")
          pos2 = index($0, " *")

          if (pos1 == 0) pos1 = length($0) + 1
          if (pos2 == 0) pos2 = length($0) + 1
          path_start = (pos1 < pos2) ? pos1 : pos2

          path = substr($0, path_start + 2)
          if (!(path in remove)) print $0
        }' "$RFL" "$OCF" > "$NCF"

      CHANGE="true"
    else
      log "  No files to remove"
      cp "$OCF" "$NCF"
    fi
    log
    if [ -s "$NFL" ];  then
      log "  Calculate checksums for new files. New file count: "$(wc -l < "$NFL")
      while IFS= read -r NEWFILE ; do
        log "    > $NEWFILE"
        sha1sum -b "$NEWFILE" >> "$NCF"
      done < "$NFL"
      CHANGE="true"
    fi
    log
    if [ "$CHANGE" = "true" ]; then
      log "  Archive and overwrite"
      cp -v "$CHECKSUMFILE" "$CHECKSUMFILE.sha1-backup-$(date -u +%Y%m%d-%H%M%S)" | sed -e 's/^/  /'
      cp -v "$NCF" "$CHECKSUMFILE" | sed -e 's/^/  /'
    else
      log "  Checksum file is valid, no need to update"
    fi
  else
    # Not fixing just logging
    if [ -s "$RFL" ] ; then
      log "  There are missing files, no changes will be made, skip removal. Missing files:"
      while IFS= read -r REMOVEDFILE ; do
        log "    > $REMOVEDFILE"
      done < "$RFL"
    else
      log "  No files to remove"
    fi
    log
    if [ -s "$NFL" ];  then
      log
      echo "  There are new files, no changes will be made, skip checksum calculation. New files:"
      while IFS= read -r NEWFILE ; do
        log "    > $NEWFILE"
      done < "$NFL"
      log
    else
      log "  No new files"
    fi
  fi


  log
  log
  log "  File count:                     "$(wc -l < "$FL")
  log "  Original checksum entries:      "$(wc -l < "$OCF")
  log "  Original checksum unique paths: "$(wc -l < "$OCFFL")
  log "  Actual (new) file count:        "$(wc -l < "$NFL")
  log "  Removed file count:             "$(wc -l < "$RFL")
  if [ "$CHANGE" = true ]; then
    log "  New checksum entries:           "$(wc -l < "$NCF")
    log "  New checksum unique path count: "$(sed -e 's/^[^ ]* .\(.*\)/\1/' "$NCF" | sort -u | wc -l)
  fi
  log
  log
  log

}


log "**************************************************************************************************************"
log "**************************************************************************************************************"
log "**"
log "**  SHA1 checksums consistency report"
log "**"
log "** Current path:               $(pwd)"
log "** Do fixes:                   $FIX_MODE"
log "** Target:                     $TARGET"
log "** Output directory:           $OD"
log "** Logfile:                    $LOGFILE"
log "** List of all checksum files: $ALLCHECKSUMFILES"
log "**"
log "**************************************************************************************************************"
log "**************************************************************************************************************"
log
log
log



# Determine if target is a checksum file or directory
if [[ -f "$TARGET" ]]; then
  log "Single file check - target is a file: $TARGET"
  log

  echo "$TARGET" > "$ALLCHECKSUMFILES"

  ALLCT=1

  visit "$TARGET"

elif [[ -d "$TARGET" ]]; then
  log "Target is a directory, searching for 'all.sha' files in: $TARGET"

  SRCDIR=$(readlink -m "$TARGET")

  log "Absolute path: $SRCDIR"
  log

  cd "$SRCDIR"

  log "Finding all checksum files to process"
  find -type f -wholename '*/all.sha1' > "$ALLCHECKSUMFILES"

  ALLCT=$(wc -l < "$ALLCHECKSUMFILES")
  log "  Found: $ALLCT checksum files"
  log

  while IFS= read -r CHECKSUMFILE ; do
    cd "$SRCDIR"
    visit "$CHECKSUMFILE"
  done < "$ALLCHECKSUMFILES"

else
  echo "Error: Target '$TARGET' is neither a file nor a directory."
  exit 1
fi

log "=============================================================================================================="
log "All done."
log "=============================================================================================================="
