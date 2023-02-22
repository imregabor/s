#!/bin/bash
#
# Write exif info list
#
#

TS=$(date -Iseconds)
OF="./all-${TS}.exifinfo"
LOF="./all-${TS}.filelist"

echo "Create full file list to $LOF"
echo

CT=0
while read line ; do
  CT=$(( CT + 1 ))
  if [ $(( CT % 1000 )) == 0 ] ; then
    echo "  listed $CT files so far"
  fi
done < <(find . -type f | grep -v "^\./\$RECYCLE.BIN" | grep -v "^\./System Volume Information" | grep "jpg$\|jpeg$\|JPG$\|JPEG$" | tee "$LOF" )
echo "  listing done; listed file count: $CT."
echo

OCT=CT
CT=0
while read line ; do
  CT=$(( CT + 1 ))
  if [ $(( CT % 100 )) == 0 ] ; then
    echo "  exif info extracted  $CT (of $OCT) files so far"
  fi
  EI=$(identify \
    -format '%[exif:make]|%[exif:model]|%[exif:datetime]|%[exif:focallength] mm %[exif:exposuretime] s f %[exif:fnumber] ISO %[exif:photographicsensitivity]' \
    "$line"| sed -e 's/ *|/|/g')
  echo -e "$EI\t$line" >> "$OF"
done < "$LOF"

echo
echo
echo
echo "All done, stats:"
echo
echo
echo "Number of lines in $OF  (exif info list):   "$(wc -l < "$OF")
echo "Number of lines in $LOF (all files listed): "$(wc -l < "$LOF")
echo
echo
