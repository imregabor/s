#!/bin/bash
#
# Create multiple listings of the current directory:
#
#  - List of all files
#  - Output of recursive ls
#  - Union of SHA1 checksums + dedup (paths rebased to PWD to keep valid)
#  - Directory size (in bytes) report for all dirs
#  - List of git remotes for git repos
#
# When an empty file matching glob ___*___*___ is present it will be treated as
# a <DISK ID>, write the listings into ./___listings___/<DISK_ID>/
# In this case paths in the union of SHA1 cheksums files wont be further rebased.
# Checksums from under ./___listings___ wont be harvested regardless of the output
# directory.
#

# TS=$(date -Iseconds)
TS=$(date -u +"%Y-%m-%d___%H-%M-%S")

BASEDIR="."

if [ -f ./___*___*___ ] ; then

  # An empty file matching above pattern identifies the disk / tree where this listing is launched
  # Write the listings into ./___listings___/<DISK_ID>/ instead

  disk_id_file=$(echo ___*___*___)
  disk_id_size=$(stat -c %s "$disk_id_file")

  if [ "$disk_id_size" == 0 ]; then
    echo
    echo "Disk ID file found: \"$disk_id_file\""
    BASEDIR="./___listings___/$disk_id_file/$TS"
    echo "  All listing files will be written into outout dir $BASEDIR"
    echo "  Note that paths are not altered, they kept relative to ."
    echo
    mkdir -p "$BASEDIR"
  else
    echo "ERROR. Non-empty disk ID file candidate \"$disk_id_file\" ($disk_id_size bytes) found. Disk ID file is expected to be empty, exiting"
    exit 1
  fi
fi

LOF="${BASEDIR}/all-${TS}.filelist"
SOF_TMP="${BASEDIR}/all-${TS}.sha1.tmp"
SOF="${BASEDIR}/all-${TS}.sha1"
LSR="${BASEDIR}/all-${TS}.lsr"
DUF="${BASEDIR}/all-${TS}.du"
GRS="${BASEDIR}/all-${TS}.gitrepos"


echo "Create full file list using base dir $BASEDIR"
echo
echo "  List of files:                         $LOF"
echo "  All SHA1 sums:                         $SOF"
echo "  All SHA1 sums temp file:               $SOF_TMP"
echo "  ls -lAR --time-style=full-iso listing: $LSR"
echo "  du report:                             $DUF"
echo "  collection of git remotes:             $GRS"
echo

CT=0
while read line ; do
  CT=$(( CT + 1 ))
  if [ $(( CT % 1000 )) == 0 ] ; then
    echo "  listed $CT files so far (last file: \"$line\")"
  fi
done < <(find . -type f | grep -av "^\./\$RECYCLE.BIN" | grep -av "^\./System Volume Information" | tee "$LOF" )
echo "  listing done; listed file count: $CT."
echo

echo "Create recursive ls -r into $LSR"
ls -lAR --time-style=full-iso > "$LSR"

echo "Collect already calculated sha1s into $SOF_TMP"

rm -f "$SOF_TMP"

while read line ; do
  BD=$(echo "$line" | sed -e 's/^\(.*\/\).*$/\1/')
  echo "Process sha1sum file $line; BD: $BD"
  cat "$line" | awk "{
    sum=substr(\$0,1,42);

    p0=substr(\$0,43,1);
    pl=substr(\$0,43,2);

    if ( pl == \"./\") {
      rp=substr(\$0,45);
      print sum \"$BD\" rp
    } else if ( p0 != \"-\" && p0 != \"/\") {
      rp=substr(\$0,44);
      print sum \"$BD\" rp
    }
  }" >> "$SOF_TMP"
done < <(cat "$LOF" | grep -a "\.sha1$" | grep -v "^\./___listings___/")

echo "Dedup $SOF_TMP into $SOF"
rm -f "$SOF"
# see https://stackoverflow.com/questions/37514283/gnu-sort-default-buffer-size
sort -u "$SOF_TMP" > "$SOF"

echo
echo "Collect directory DU report"
du --apparent-size -b > "$DUF"

echo
echo "Collect git repos into $GRS"


find -type d -name '.git' | while read dir; do
  remote=$(git -C "$dir" remote -v | grep '(fetch)' | sed -e 's/.fetch.$//' | sed -e 's/^origin.//')
  echo -e "$dir\t$remote"
done | tee -a "$GRS"


echo
echo "Calculate SHA1 sum of listing files "
sha1sum -b "$LOF" >> "$SOF"
sha1sum -b "$LSR" >> "$SOF"
sha1sum -b "$DUF" >> "$SOF"
sha1sum -b "$GRS" >> "$SOF"


echo
echo
echo
echo "All done, stats:"
echo
echo "  files list:         $(wc -l < "$LOF") lines ($LOF)"
echo "  recursive ls -R:    $(wc -l < "$LSR") lines ($LSR)"
echo "  du report:          $(wc -l < "$DUF") lines ($DUF)"
echo "  sha1 tmp checksums: $(wc -l < "$SOF_TMP") lines ($SOF_TMP)"
echo "  sha1 checksums:     $(wc -l < "$SOF") lines ($SOF)"
echo "  git repo remotes:   $(wc -l < "$GRS") lines ($GRS)"
echo
echo
