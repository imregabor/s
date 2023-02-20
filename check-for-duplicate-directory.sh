#!/bin/bash
#

CANDIDATE=""
TARGET=""
NAME=false
SHA1=false

function usage() {
  echo
  echo "ERROR: $1"
  echo
  echo "usage:"
  echo
  echo "  $0 [-name] [-sha1] -candidate <DIR> -target <DIR>"
  echo


  exit -1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -candidate)
      shift
      CANDIDATE=$(readlink -m "$1")
      shift
      ;;
    -target)
      shift
      TARGET=$(readlink -m "$1")
      shift
      ;;
    -name)
      shift
      NAME=true
      ;;
    -sha1)
      shift
      SHA1=true
      ;;
    *)
      usage "Unknown argument $1"
      shift
      ;;
  esac
done

if [ ! -d "$CANDIDATE" ] ; then
  usage "candidate dir not found: $CANDIDATE"
fi

if [ ! -d "$TARGET" ] ; then
  usage "target dir not found: $TARGET"
fi

if [ "$NAME" == false ] && [ "$SHA1" == false ] ; then
  usage "no checks selected"
fi



if [ "$NAME" == true ] ; then
  echo "Check for simple name matches"
  echo

  echo "Listing base names for candidate directory"
  CN=$(find "$CANDIDATE" -type f | sed -e 's/.*\///' | sort -u)
  UCN=$(echo "$CN" | sort -u)
  echo " done."
  echo " File count:        "$(wc -l < <(echo "$CN"))
  echo " Unique base names: "$(wc -l < <(echo "$UCN"))
  echo

  echo "Listing base names for target directory"
  TN=$(find "$TARGET" -type f | sed -e 's/.*\///' | sort -u)
  UTN=$(echo "$TN" | sort -u)
  echo " done."
  echo " File count:        "$(wc -l < <(echo "$TN"))
  echo " Unique base names: "$(wc -l < <(echo "$UTN"))
  echo

  CON=$(comm -23 <(echo "$UCN") <(echo "$UTN"))
  if [ -z "$CON" ] ; then
    echo "No unique candidate file names found"
  else
    echo "Unique candidate file names (found "$(wc -l < <(echo "$CON"))" files)"
    echo
    echo "$CON"
  fi

  echo
  echo
fi

if [ "$SHA1" == true ]; then
  echo "Do strict SHA1 checksum based check"
  echo

  echo "Calculate SHA1 checksums for candidate files"
  CS=$(find "$CANDIDATE" -type f | xargs -I '{}' sha1sum -b '{}')
  echo "  done."
  echo "  File count: "$(wc -l < <(echo "$CS"))
  echo

  echo "Calculate SHA1 checksums for for target files"
  TS=$(find "$TARGET" -type f | xargs -I '{}' sha1sum -b '{}')
  echo "  done."
  echo "  File count: "$(wc -l < <(echo "$TS"))
  echo


  COS=$(comm -23 <(echo "$CS" | cut -f 1 -d " " | sort)  <(echo "$TS" | cut -f 1 -d " " | sort))

  if [ -z "$COS" ] ; then
    echo "No unique candiate checksum found"
  else
    echo "Unique candidate checksums (found "$(wc -l < <(echo "$COS"))" files)"
    echo
    echo "$COS"
  fi
fi