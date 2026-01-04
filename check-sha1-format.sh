#!/bin/bash
#
# Check SHA1 file for formatting errors
#
# This check is stricter than the possible valid outputs emitted (and consumed) by sha1sum.
# Output conventions described at https://www.gnu.org/software/coreutils/manual/html_node/cksum-output-modes.html apply:
# When file name contains backslash, newline or carriage return characters, sha1sum will start
# the checksum line with a backslash, and uses it for escaping characters in the path part.
#
# These escaped checksum lines are reported as format errors by this tool.
#
# To find offending files use
#
#  LC_ALL=C find \( -name '*\\*' -o -name \*$'\n'\* -o -name \*$'\r'\* \)

set -e

if ! command -v readlink &> /dev/null; then
  echo "Error: readlink is not available."
  exit 1
fi


usage() {
  echo
  echo "Check/report SHA1 checksum file format. No attempt to fix just logs on stdout."
  echo
  echo "Usage:"
  echo
  echo "  $0 [-h] [-v] <TARGET_PATH>"
  echo
  echo "<TARGET_PATH> Target location:"
  echo
  echo "  If points to a checksum file it will be checked."
  echo
  echo "  If points to a directory it will be searched for \"all.sha1\" files,"
  echo "  all hits will be processed."
  echo
  echo "Options:"
  echo "  -h,   --help           Print this help and exit."
  echo "  -v,   --verbose        Be verbose, print currently checked file"
  echo
  exit 1
}

TARGET=""
VERBOSE=false

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -v|--verbose)
      VERBOSE=true
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

log() {
  echo "$@"
}

# Procesed checksum file count
CT=0
# Number of checksum files with error(s)
FORMAT_ERROR_COUNT=0
DUPES_ERROR_COUNT=0
FORMAT_ERRORS_MSG=""
DUPES_ERRORS_MSG=""


process_checksum_file() {
  local CHECKSUMFILE
  CHECKSUMFILE=$(readlink -m "$1")

  CT=$((CT + 1))

  if [ "$VERBOSE" == true ] ; then
    log "Checking file $CT$FORMAT_ERRORS_MSG$DUPES_ERRORS_MSG: $CHECKSUMFILE"
    PRINT_FILENAME=false
  else
    PRINT_FILENAME=true
  fi




  if grep -av '^[0-9a-z]\{40,40\} [ \*]\./' "$CHECKSUMFILE" > /dev/null; then
    if [ "$PRINT_FILENAME" == true ] ; then
      log "Problem(s) in file $CHECKSUMFILE:"
      PRINT_FILENAME=false
    fi
    FORMAT_ERROR_COUNT=$((FORMAT_ERROR_COUNT + 1))
    FORMAT_ERRORS_MSG=" ($FORMAT_ERROR_COUNT format errors so far)"
    log
    log "  ** Formatting problem ($FORMAT_ERROR_COUNT) **"
    log
    while IFS= read -r LINE; do
      log "    > $LINE"
    done < <(grep -anv '^[0-9a-z]\{40,40\} [ \*]\./' "$CHECKSUMFILE")
    log
  fi

  dupes=$(sed -E 's|^[^ ]* .(.*)|\1|' "$CHECKSUMFILE" | sort | uniq -d)
  if [[ "$dupes" ]]; then
    if [ "$PRINT_FILENAME" == true ] ; then
      log "Problem(s) in file $CHECKSUMFILE:"
      PRINT_FILENAME=false
    fi
    DUPES_ERROR_COUNT=$((DUPES_COUNT + 1))
    DUPES_ERRORS_MSG=" ($DUPES_ERROR_COUNT dupes errors so far)"
    log "  ** Duplicate paths problem ($DUPES_ERROR_COUNT) **"
    while IFS= read -r DUPLICATE_PATH; do
      log "    > $DUPLICATE_PATH"
    done < <(echo "$dupes")
  fi
}


if [[ -f "$TARGET" ]]; then
  log "Single file check - target is a file: $TARGET"
  log

  process_checksum_file "$TARGET"

elif [[ -d "$TARGET" ]]; then
  log "Target is a directory, searching for 'all.sha' files in: $TARGET"

  SRCDIR=$(readlink -m "$TARGET")

  if [ "$VERBOSE" == true ] ; then
    log "Absolute path: $SRCDIR"
  fi

  cd "$SRCDIR"

  while IFS= read -r CHECKSUMFILE ; do
    process_checksum_file "$CHECKSUMFILE"
  done < <(LC_ALL=C find -type f -wholename '*/all.sha1')

else
  echo "Error: Target '$TARGET' is neither a file nor a directory."
  exit 1
fi

log
log
log "=============================================================================================================="
log "All done."
log "  Checked checksum files:              $CT"
log "  Checksum files with format errors:   $FORMAT_ERROR_COUNT"
log "  Checksum files with duplicate paths: $DUPES_ERROR_COUNT"
log "=============================================================================================================="
log
log
