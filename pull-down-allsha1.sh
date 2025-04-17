#!/bin/bash
#
# Pull and adjust relevane contents from all.sha1 files into ./all.sha1 from parent dirs
#
#

OF=$(readlink -m "./all.sha1")
if [ -e "$OF" ] ; then
  echo "ERROR! Output  \"$OF\" already exists, exiting."
  exit -1
fi

OFTMP=$(readlink -m "./all.sha1-inprogress")
if [ -e "$OFTMP" ] ; then
  echo "ERROR! Output temp location \"$OFTMP\" already exists, exiting."
  exit -1
fi


SUMFILECT=0
SUMLINECT=0
LC_ALL=C

PREFIX="$(readlink -m "$PWD")"
PREFIX="$(basename "$PREFIX")/"
cd ..
while [ "$PWD" != "/" ]; do
  INFILE="$PWD/all.sha1"
  echo "Looking for $INFILE"
  if [ -f "$INFILE" ]; then
    PREFIX="./$PREFIX"
    echo "  found:  $INFILE"
    echo "  prefix: $PREFIX"
    echo
    grep -aF "$PREFIX" "$INFILE" |
      awk -v prefix="$PREFIX" '{ i = index($0, prefix); print substr($0, 0, i) substr($0, i + length(prefix) - 1);   }' > "$OFTMP"
    echo "  rename $OFTMP -> $OF"
    mv "$OFTMP" "$OF"
    echo "  done, checksum count: "$(wc -l < "$OF")
    exit 0
  fi

  DN="$(readlink -m "$PWD")"
  DN="$(basename "$DN")"
  PREFIX="$DN/$PREFIX"
  cd ..

done

echo "No all.sha1 file was found in any of the parents"
exit -1
