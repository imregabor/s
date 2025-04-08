#!/bin/bash
#
# Report sync between FS and "all.sha1" checksum files
#

set -e

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
  echo "  -h,  --help         Print this help and exit."
  echo "  -fn, --fix-new      Fix checksum file(s) in case of new file discrepancy - calculate checksum for new files."
  echo "  -fd, --fix-deleted  Fix checksum file(s) in case of deleted file discrepancy - remove missing file from checksum."
  echo
  exit 1
}

# Default values
FIX_NEW=false
FIX_DELETED=false
TARGET=""

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -fn|--fix-new)
      FIX_NEW=true
      shift
      ;;
    -fd|--fix-deleted)
      FIX_DELETED=true
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
INDIVIDUAL_MISSING_FILES_LIST="$OD/all-missing-files.txt"
INDIVIDUAL_ADDED_FILES_LIST="$OD/all-new-files.txt"

mkdir -p "$OD" || { echo "Error: Failed to create output report directory '$OD'." >&2; exit 1; }

log() {
  echo "$@" | tee -a "$LOGFILE"
}


# Procesed checksum file count
CT=0
# All checksum file count
ALLCT=0

# Unchanged checksum file count
CT_UNCHANGED=0

# Changed checksum file count
CT_CHANGED=0

# Checksum files involved in additions
CT_ADDED=0

# Checksum files involved in removal
CT_REMOVED=0

# Individual files missing but referenced in all checksums (might be duplicated)
CT_TOTAL_MISSING_FILES=0

# Number of file entries missing from checksums (might be duplicated)
CT_TOAL_ADDED_FILES=0

# All checksum files encountered
ALLCHECKSUMFILES="$OD/all-checksum-files.txt"

process_checksum_file() {
  local CHECKSUMFILE
  CHECKSUMFILE=$(readlink -m "$1")

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
  if [ "$FIX_NEW" = true ] || [ "$FIX_DELETED" = true ]; then
    log "= Updated checksum file:         $NCF"
  fi
  log "="
  log "=============================================================================================================="
  log

  mkdir -p "$RD"
  echo "$CD" > "$RD/pwd.txt"

  log "  Archive original checksum file to $OCF"
  cp -v "$CHECKSUMFILE" "$OCF" | sed -e 's/^/    /'
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

  CHANGE=false

  log

  if [ -s "$RFL" ] ; then
    MISSING_FILES=$(wc -l < "$RFL")

    CT_REMOVED=$((CT_REMOVED+1))
    CT_TOTAL_MISSING_FILES=$((CT_TOTAL_MISSING_FILES+MISSING_FILES))
    CHANGE=true
    log "  Files referenced in checksum but not found (removed on FS) count: $MISSING_FILES"

    if [ "$FIX_DELETED" = true ]; then
      log "  Remove checksums for missing files"
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
    else
      log "  No removal from checksum will be made."
    fi

    log "  Missing files:"
    while IFS= read -r REMOVEDFILE ; do
      log "    > $REMOVEDFILE"
      echo $(readlink -m "$REMOVEDFILE") >> "$INDIVIDUAL_MISSING_FILES_LIST"
    done < "$RFL"
  else
    log "  No files removed from the FS"
    if [ "$FIX_NEW" = true ] || [ "$FIX_DELETED" = true ]; then
      # New checksum file is not written when no fix is requested
      cp "$OCF" "$NCF"
    fi
  fi

  if [ -s "$NFL" ];  then
    ADDED_FILES=$(wc -l < "$NFL")

    CT_ADDED=$((CT_ADDED+1))
    CT_TOTAL_ADDED_FILES=$((CT_TOTAL_ADDED_FILES+ADDED_FILES))
    CHANGE=true
    log "  Added files found but missing from checksums (added on FS) count: $ADDED_FILES"

    if [ "$FIX_NEW" = true ]; then
      log "  Calculate checksums for added files"
      while IFS= read -r NEWFILE ; do
        log "    > $NEWFILE"
        sha1sum -b "$NEWFILE" >> "$NCF"
        echo $(readlink -m "$NEWFILE") >> "$INDIVIDUAL_ADDED_FILES_LIST"
      done < "$NFL"
    else
      log "  No checksum calculation for new files will be done. Added files:"
      while IFS= read -r NEWFILE ; do
        log "    > $NEWFILE"
        echo $(readlink -m "$NEWFILE") >> "$INDIVIDUAL_ADDED_FILES_LIST"
      done < "$NFL"
    fi
  else
    log "  No files added to the FS"
  fi
  log

  if [ "$CHANGE" = true ]; then
    CT_CHANGED=$((CT_CHANGED+1))

    if [ "$FIX_NEW" = true ] || [ "$FIX_DELETED" = true ]; then
      log "  Archive and overwrite"
      cp -v "$CHECKSUMFILE" "$CHECKSUMFILE.sha1-backup-$(date -u +%Y%m%d-%H%M%S)" | sed -e 's/^/    /'
      cp -v "$NCF" "$CHECKSUMFILE" | sed -e 's/^/    /'
    fi

  else
    CT_UNCHANGED=$((CT_UNCHANGED+1))

    if [ "$FIX_NEW" = true ] || [ "$FIX_DELETED" = true ]; then
      log "  Checksum file is in sync with FS, no need to update"
    fi
  fi

  log
  log
  log "  File count:                     "$(wc -l < "$FL")
  log "  Original checksum entries:      "$(wc -l < "$OCF")
  log "  Original checksum unique paths: "$(wc -l < "$OCFFL")
  log "  Actual (new) file count:        "$(wc -l < "$NFL")
  log "  Removed file count:             "$(wc -l < "$RFL")
  if [ "$FIX_MODE" = true ]; then
    log "  New checksum entries:           "$(wc -l < "$NCF")
    log "  New checksum unique path count: "$(sed -e 's/^[^ ]* .\(.*\)/\1/' "$NCF" | sort -u | wc -l)
  fi
  log
  log "  Valid checksum files so far: $CT_UNCHANGED, invalid: $CT_CHANGED, +: $CT_ADDED, -: $CT_REMOVED"
  log "    Individual missing files referenced in checksums so far: $CT_TOTAL_MISSING_FILES"
  log "    Infividual new files not referenced in checksums so far: $CT_TOTAL_ADDED_FILES"
  log
  log
  log
}


log "**************************************************************************************************************"
log "**************************************************************************************************************"
log "**"
log "**  SHA1 checksums consistency report"
log "**"
log "** Current path:                     $(pwd)"
log "** Do fix new files (calc checksum): $FIX_NEW"
log "** Do fix deleted (remove checksum): $FIX_DELETEDS"
log "** Target:                           $TARGET"
log "** Output directory:                 $OD"
log "** Logfile:                          $LOGFILE"
log "** List of all checksum files:       $ALLCHECKSUMFILES"
log "** List of new files:                $INDIVIDUAL_ADDED_FILES_LIST"
log "** List of removed files:            $INDIVIDUAL_MISSING_FILES_LIST"
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

  process_checksum_file "$TARGET"

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
    process_checksum_file "$CHECKSUMFILE"
  done < "$ALLCHECKSUMFILES"

else
  echo "Error: Target '$TARGET' is neither a file nor a directory."
  exit 1
fi

log "=============================================================================================================="
log "All done."
log "  Valid checksum files so far: $CT_UNCHANGED, invalid: $CT_CHANGED, +: $CT_ADDED, -: $CT_REMOVED"
log "    Individual missing files referenced in checksums so far: $CT_TOTAL_MISSING_FILES"
log "    Infividual new files not referenced in checksums so far: $CT_TOTAL_ADDED_FILES"
log "=============================================================================================================="
