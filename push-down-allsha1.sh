#!/bin/bash
#
# Push down checksums 1 dir lower
#
#

IF="./all.sha1"
if [ ! -f "$IF" ] ; then
  echo "ERROR! Input file $IF not found, exiting."
  exit -1
fi

INCT=0
SKIPCT=0
PUSHCT=0

echo "Pushing down checksums from $IF one directory level deeper"

while read line ; do
  INCT=$(( INCT + 1 ))

  if [[ "$line" =~ ^([a-fA-F0-9]+\ .\.\/)([^/]+)/(.*)$ ]] ; then
    PREFIX=${BASH_REMATCH[1]} # ends with ./
    DIRNAME=${BASH_REMATCH[2]} # dir without leading or trailing /
    RELPATH=${BASH_REMATCH[3]} # relative path without leadingh ./

    if [ ! -d "./${DIRNAME}" ] ; then
      echo "  Dir \"${DIRNAME}\" not found, skipping; line: $line"
      SKIPCT=$(( SKIPCT + 1 ))
    else
      echo "${PREFIX}${RELPATH}" >> "./${DIRNAME}/all.sha1"
      PUSHCT=$(( PUSHCT + 1 ))
    fi
  else
    SKIPCT=$(( SKIPCT + 1 ))
    echo "  Skipping $line"
  fi
done < <(cat "$IF")


echo
echo "All done."
echo "  Input checksum count: $INCT"
echo "  Pushed down count:    $PUSHCT"
echo "  Skipped line count:   $SKIPCT"
echo
echo
