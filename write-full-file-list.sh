#!/bin/bash
#
# Write file list, recursive ls and collect all calculated sha1 checksums
#
#

TS=$(date -Iseconds)
LOF="./all-${TS}.filelist"
SOF="./all-${TS}.sha1"
LSR="./all-${TS}.lsr"

echo "Create full file list to $LOF"
echo

CT=0
while read line ; do
  CT=$(( CT + 1 ))
  if [ $(( CT % 1000 )) == 0 ] ; then
    echo "  listed $CT files so far"
  fi
done < <(find . -type f | grep -v "^\./\$RECYCLE.BIN" | grep -v "^\./System Volume Information" | tee "$LOF" )
echo "  listing done; listed file count: $CT."
echo

echo "Create recursive ls -r into $LSR"
ls -lAR --time-style=full-iso > "$LSR"

echo "Collect already calculated sha1s into $SOF"

rm -f "$SOF"

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
  }" >> "$SOF"


done < <(cat "$LOF" | grep "\.sha1$")

sha1sum -b "$LOF" >> "$SOF"
sha1sum -b "$LSR" >> "$SOF"

echo "Number of lines in $SOF: "$(wc -l "$SOF")
