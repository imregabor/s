#!/bin/bash
#
# Write image/video info list
#
#


usage() {
  echo
  echo "Usage: $0 [-l <FILENAME>] [-b <BASENAME>] [-h]"
  echo "  -l <FILENAME>   Use list file"
  echo "  -b <FILENAME>   Basename for work generated files"
  echo "  -h              Help"
  echo
  exit -1
}


BN="all"
LOF=""

while getopts "l:b:h" opt; do
  case ${opt} in
    l )
      LOF=${OPTARG}
      if [ ! -f "$LOF" ] ; then
        echo "ERROR! Listing file \"$LOF\" not found"
        exit -1
      fi
      ;;
    b )
      BN=${OPTARG}
      ;;
    h )
      usage
      ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      usage
      ;;
    : )
      echo "Option -$OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done


# Time stamp
TS=$(date -Iseconds)

# Main out file
OF="./${BN}-${TS}.exifinfo"

# Troubles file
TO="./${BN}-${TS}.troubles"

if [ -z "${LOF}" ] ; then
  # List of files
  LOF="./${BN}-${TS}.filelist"


  echo "Create full file list to $LOF"
  echo

  CT=0
  while read line ; do
    CT=$(( CT + 1 ))
    if [ $(( CT % 1000 )) == 0 ] ; then
      echo "  listed $CT files so far"
    fi
  done < <(find . -type f | grep -v "^\./\$RECYCLE.BIN" | grep -v "^\./System Volume Information" | grep '[jJ][pP][eE]\?[gG]$\|[mM][pP]4$\|[mM][oO][vV]$\|[aA][vV][iI]$' | tee "$LOF" )
  echo "  listing done; listed file count: $CT."
else
  echo "Use existing list file ${LOF}"
  CT=$(cat "${LOF}" | wc -l)
fi

echo

echo "Extracting media info into ${OF}, write troubles to ${TO}"
echo

OCT=$CT
CT=0
while read line ; do
  CT=$(( CT + 1 ))
  if [ $(( CT % 100 )) == 0 ] || [ $CT -le 100 ]; then
    echo "  exif info extracted  $CT (of $OCT) files so far"
  fi
  if echo "$line" | grep -q '[jJ][pP][eE]\?[gG]$' ; then
    EI=$(identify \
      -format '%[exif:make]|%[exif:model]|%[exif:datetimedigitized]|%[exif:focallength] mm %[exif:exposuretime] s f %[exif:fnumber] ISO %[exif:photographicsensitivity]' \
      "$line" 2>&1 | sed -e 's/ *|/|/g')
    TRB=""
    if echo "$EI" | grep -q "unknown image property" ; then
      TRB="No proper EXIF data"
    elif echo "$EI" | grep -q "exceeds limit" ; then
      TRB="Image exceeds limit"
    elif [ $(echo "$EI" | wc -l) -gt 1 ] ; then
      TRB="Multi line output from identify"
    else
      echo -e "$EI\t$line" >> "$OF"
    fi

    if [ ! -z "$TRB" ] ; then
      echo "$TRB: $line, skipping from listing"

      echo "-----------------------------------------------------------------------------" >> "$TO"
      echo -e "trouble ($TRB) with\t$line" >> "$TO"
      echo >> "$TO"
      echo "$EI" >> "$TO"
      echo >> "$TO"
    fi

  else
    SIZE=$(stat --printf="%s" "$line")
    FFP=$(ffprobe "$line" 2>&1)

    CRT=$(echo "$FFP" | grep -m 1 'creation_time' | sed -e 's/.*creation_time *: *//')

    if [ -z "$CRT" ] ; then
      echo "No creation time for $line, skipping from listing"

      echo "-----------------------------------------------------------------------------" >> "$TO"
      echo -e "trouble (no creation time) with\t$line" >> "$TO"
      echo >> "$TO"
      echo "$FFP" >> "$TO"
      echo >> "$TO"

    else
      echo -e "$CRT $SIZE bytes\t$line" >> "$OF"
    fi

  fi
done < "$LOF"

echo
echo
echo
echo "All done, stats:"
echo
echo
echo "Number of lines in $OF (exif info list):   "$(wc -l < "$OF")
echo "Number of lines in $LOF (all files listed): "$(wc -l < "$LOF")
if [ -f "$TO" ] ; then
  echo "Number of lines in $TO (troubles):          "$(wc -l < "$TO")
else
  echo "No troubles found"
fi
echo
echo
