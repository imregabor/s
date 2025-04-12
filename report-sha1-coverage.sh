#!/bin/bash
#
# Report paths not covered by "all.sha1" checksums
#

set -e

if ! command -v readlink &> /dev/null; then
  echo "Error: readlink is not available."
  exit 1
fi

usage() {
  echo
  echo "Check/report all.sha1 checksum coverage"
  echo
  echo "Usage:"
  echo
  echo "  $0 [-h] [-v] [-vv] [-ldb <DIRECTORY>] <CHECK_ROOT_DIRECTORY>"
  echo
  echo "<CHECK_ROOT_DIRECTORY> Directory to check."
  echo
  echo "Options:"
  echo "  -h,   --help           Print this help and exit."
  echo "  -v,   --verbose        Be more verbose. Note that verbose log file is always written."
  echo "  -vv,  --very-verbose   Be more verbose and print (on verbose level) even further details. Implies -v."
  echo "  -ldp, --log-dir-parent Parent dir for log / report directory. By default make log / report dir in current dir."
  echo
  exit 1
}

# Default values
TARGET=""
VERBOSE=false
VERYVERBOSE=false
ODP=$(readlink -m ".")

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      shift # not really needed, be consistent
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -vv|--very-verbose)
      VERBOSE=true
      VERYVERBOSE=true
      shift
      ;;
    -ldp|--log-dir-parent)
      shift
      ODP="$1"
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

if [[ -z "$ODP" ]]; then
  echo "Error: Log/report dir parent is not specified"
  echo
  usage
fi

if [[ ! -d "$ODP" ]]; then
  echo "Error: Log/report dir parent is not found: $ODP"
  echo
  usage
fi

# Ensure target is provided
if [[ -z "$TARGET" ]]; then
  echo "Error: No target directory is specified."
  echo
  usage
fi

# Ensure target is provided
if [[ ! -d "$TARGET" ]]; then
  echo "Target dir not found: $TARGET"
  echo
  usage
fi

# Output dir for report
OD=$(readlink -m "$ODP/sha1-coverage-report-$(date -u +%Y%m%d-%H%M%S)")
LOGFILE="$OD/report.log"
VLOGFILE="$OD/report-verbose.log"

mkdir -p "$OD" || { echo "Error: Failed to create output report directory '$OD'." >&2; exit 1; }

log() {
  echo "$@" | tee -a "$LOGFILE"
}

vlog() {
  if [[ "$VERBOSE" == true ]]; then
    echo "$@" | tee -a "$VLOGFILE"
  else
    echo "$@" >> "$VLOGFILE"
  fi
}

# All checksum files encountered
ALLCHECKSUMFILES="$OD/all-checksum-files.txt"
ALLDIRECTORIES="$OD/all-directories.txt"


log
log
log
log "**************************************************************************************************************"
log "**************************************************************************************************************"
log "**"
log "**  SHA1 checksum coverage report"
log "**"
log "** Current path:                     $(pwd)"
log "** Target:                           $TARGET"
log "** Output directory:                 $OD"
log "** Parent of output directory:       $ODP"
log "** Log file:                         $LOGFILE"
log "** Verbose log file:                 $VLOGFILE"
if [[ "$VERYVERBOSE" == true ]]; then
  log "** Very Verbose details will be printed"
fi
log "**"
log "** List of all checksum files:       $ALLCHECKSUMFILES"
log "** List of all directories:          $ALLDIRECTORIES"
log "**"
log "**************************************************************************************************************"
log "**************************************************************************************************************"
log
log
log

SRCDIR=$(readlink -m "$TARGET")


cd "$SRCDIR"

log "Searching for 'all.sha1' files in: $SRCDIR"
find -type f -wholename '*/all.sha1' | sort -u > "$ALLCHECKSUMFILES"
CHECKSUMFILE_COUNT=$(wc -l < "$ALLCHECKSUMFILES")
log "  Found: $CHECKSUMFILE_COUNT checksum files"
log

log "Searching for all directories in: $SRCDIR"
find -type d | sort -u > "$ALLDIRECTORIES"
DIRECTORY_COUNT=$(wc -l < "$ALLDIRECTORIES")
log "  Found: $DIRECTORY_COUNT directories"
log

log "Read into arrays"
log

mapfile -t COVERED_DIRS < <(sed 's|/all\.sha1$||' "$ALLCHECKSUMFILES")
mapfile -t ALL_DIRS < "$ALLDIRECTORIES"

is_covered_by_checksum() {
  local dir="$1"
  if [[ "$VERYVERBOSE" == true ]]; then
    vlog "    Check coverage status of directory \"$dir\""
  fi

  for covered_dir in "${COVERED_DIRS[@]}"; do
    if [[ "$dir" = "$covered_dir" || "$dir" == "$covered_dir/"* ]]; then
      if [[ "$VERYVERBOSE" == true ]]; then
        vlog "        covered by directory \"$covered_dir\""
      fi

      return 0
    fi
  done
  return 1
}

log "Identify all uncovered directories"
UNCOVERED=()
UNCOVERED_COUNT=0
NR_UNCOVERED_COUNT=0
for dir in "${ALL_DIRS[@]}"; do
  if ! is_covered_by_checksum "$dir"; then
    vlog "  > $dir"
    UNCOVERED+=("$dir")
    UNCOVERED_COUNT=$((UNCOVERED_COUNT + 1))
  fi
done

if [[ "${#UNCOVERED[@]}" -eq 0 ]]; then
  log
  log "No uncovered directories, all clear"
else
  log "  Total uncovered directories: $UNCOVERED_COUNT"
  log
  if [[ "$VERYVERBOSE" == true ]]; then
    vlog
    for uncovered_dir in "${UNCOVERED[@]}"; do
      vlog "    Uncovered: \"$uncovered_dir\""
    done
    vlog
  fi


  
  log "Checking for uncovered dirs with covered sibling. These are recommended candidates for further checksum calculation."
  for uncovered_dir in "${UNCOVERED[@]}"; do
    if [[ "$uncovered_dir" == "." ]]; then
      continue
    fi
    parent_of_uncovered=$(dirname "$uncovered_dir")
    for covered_dir in "${COVERED_DIRS[@]}"; do
      parent_of_covered=$(dirname "$covered_dir")
      if [[ "$parent_of_covered" == "$parent_of_uncovered" ]]; then
        log "  $(readlink -m "$uncovered_dir")"
        break
      fi
    done
  done
  log

  log "Highest level uncovered directories. Generating here might cover checksum files deeper."
  while IFS= read -r DIR ; do
    NR_UNCOVERED_COUNT=$((NR_UNCOVERED_COUNT + 1))
    log "  $(readlink -m "$TARGET/$DIR")"
  done < <(printf "%s\n" "${UNCOVERED[@]}" | sort | awk '{
    for (i in seen) {
      if (index($0, seen[i]) == 1 && ($0 == seen[i] || substr($0, length(seen[i])+1, 1) == "/")) {
        next
      }
    }
    seen[++n] = $0
    print
  }')
  log
fi

log
log
log "=============================================================================================================="
log
log "All done."
log
log "  Checksum file count:                  $CHECKSUMFILE_COUNT"
log "  Directory count:                      $DIRECTORY_COUNT"
log "  Individual unvovered directory count: $UNCOVERED_COUNT"
log "  Non-redundant uncovereds:             $NR_UNCOVERED_COUNT"
log
log "=============================================================================================================="
log
log

