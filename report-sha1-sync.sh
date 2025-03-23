#!/bin/bash
#
# Report sync between FS and "all.sha1" checksum files
#

if ! command -v readlink &> /dev/null; then
  echo "Error: readlink is not available."
  exit 1
fi


if [ "$#" -lt 1 ] || [ "$#" -gt 1 ]; then
  echo "Usage: $0 <directory_to_search_for_checksum_files>"
  exit 1
fi

if [ ! -d "$1" ]; then
  echo "Error: Search directory '$1' not found."
  exit 1
fi

SRCDIR=$(readlink -m "$1")
OD=$(readlink -m "./sha1-checksum-consistency-report-$(date -u +%Y%m%d-%H%M%S)")
LOGFILE="$OD/report.log"

mkdir -p "$OD" || { echo "Error: Failed to create output directory '$OD'." >&2; exit 1; }
log() {
  echo "$1" | tee -a "$LOGFILE"
}

log "**************************************************************************************************************"
log "**************************************************************************************************************"
log "**"
log "**  SHA1 checksums consistency report"
log "**"
log "** Current path:     $(pwd)"
log "** Search dir        $SRCDIR"
log "** Output directory: $OD"
log "** Logfile:          $LOGFILE"
log "**"
log "**************************************************************************************************************"
log "**************************************************************************************************************"
log
log
log


cd "$SRCDIR"

CT=0

while IFS= read -r CHECKSUMFILE ; do
  CT=$((CT + 1))
  RD="$OD/report-"$(printf "%04d" "$CT")
  CD=$(dirname "$CHECKSUMFILE")
  FL="$RD/file-list.txt"
  OCF="$RD/all.sha1-original"
  OCFFL="$RD/file-list-from-original-checksum-file.txt"
  NFL="$RD/new-file-list.txt"
  RFL="$RD/removed-file-list.txt"
  NCF="$RD/all.sha1-new"

  log "=============================================================================================================="
  log "="
  log "= Processing checksum file #$CT: $CHECKSUMFILE"
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
  log "= New checksum file:               $NCF"
  log "="
  log "=============================================================================================================="
  log

  mkdir -p "$RD"
  echo "$CD" > "$RD/pwd.txt"

  log "  Archive original checksum file to $OCF"
  cp "$SRCDIR/$CHECKSUMFILE" "$OCF"
  log "    file count in original checksum file: "$(wc -l < "$OCF")

  log "  Extract original checksum file list"
  cat "$SRCDIR/$CHECKSUMFILE" | sed -e 's/^[^ ]* .\(.*\)/\1/' | sort -u > "$OCFFL"
  log "    unique file count listed:             "$(wc -l < "$OCFFL")

  log "  List files"


  cd "$SRCDIR"
  cd "$CD"
  find -type f ! -name "all.sha1" ! -name "all.sha1-backup-*" | sort -u > "$FL"
  log "    files found:                          "$(wc -l < "$OCFFL")

  log "  Calculate new / removed file lists"

  comm -23 "$FL" "$OCFFL" > "$NFL"
  comm -13 "$FL" "$OCFFL" > "$RFL"

  CHANGE="false"

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

  if [ -s "$NFL" ];  then
    log "  Calculate checksums for new files. New file count: "$(wc -l < "$NFL")
    while IFS= read -r NEWFILE ; do
      log "    > $NEWFILE"
      sha1sum -b "$NEWFILE" >> "$NCF"
    done < "$NFL"

    CHANGE="true"
  else
    log "  No new files"
  fi

  if [ "$CHANGE" = "true" ]; then
    log "  Archive and overwrite"
    cp -v "./all.sha1" "./all.sha1-backup-$(date -u +%Y%m%d-%H%M%S)" | sed -e 's/^/  /'
    cp -v "$NCF" "./all.sha1" | sed -e 's/^/  /'
  else
    log "  Checksum file is valid, no need to update"
  fi

  log
  log
  log "  File count:                     "$(wc -l < "$FL")
  log "  Original checksum count:        "$(wc -l < "./all.sha1")
  log "  Checksum unique paths:          "$(wc -l < "$OCFFL")
  log "  New file count:                 "$(wc -l < "$NFL")
  log "  Removed file count:             "$(wc -l < "$RFL")
  log "  New checksum count:             "$(wc -l < "$NCF")
  log "  New checksum unique path count: "$(sed -e 's/^[^ ]* .\(.*\)/\1/' "$NCF" | sort -u | wc -l)
  log
  log
  log


done < <(find -type f -wholename '*/all.sha1')

log "=============================================================================================================="
log "All done."
log "=============================================================================================================="



