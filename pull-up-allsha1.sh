#!/bin/bash
#
# Pull contents from all.sha1 files into ./all.sha1
#
#

OF="./all.sha1"
if [ -e "$OF" ] ; then
  echo "ERROR! Output  \"$OF\" already exists, exiting."
  exit -1
fi

OFTMP="./all.sha1-inprogress"
if [ -e "$OFTMP" ] ; then
  echo "ERROR! Output temp location \"$OFTMP\" already exists, exiting."
  exit -1
fi


SUMFILECT=0
SUMLINECT=0


echo "Pulling all.sha1 checksums to \"$OF\""

while read sumfile ; do
  SUMFILECT=$(( SUMFILECT + 1 ))
  SUMLINECT=$(( SUMLINECT + $(cat "$sumfile" | wc -l ) ))

  SUMFILEPATH=$(dirname "$sumfile")


  echo "  Processing sum file: $SUMFILECT / sum lines: $SUMLINECT: \"$sumfile\""

  # in sha1sum format:       <checksum>[space][space or star]./<subpath>
  # First sed keeps:         ^^^^^^^^^^                       |        |
  # Third sed keeps:                                          ^^^^^^^^^^


  # out sha1sum format:      <checksum>[space][         star]<sumfilepath>/<subpath>
  # coming from first sed:   ^^^^^^^^^^|                                 ||        |
  # awk generates:                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|        |
  # coming from second sed:                                               ^^^^^^^^^^
  #
  # sumfilepath starts with './', does not end with '/'
  # subpath is picked with the preceding / but not the preceding .

  paste -d '' <(sed -E 's|^([^ ]+) .*|\1|' "$sumfile") \
              <(cat "$sumfile" | awk -v sumfilepath="$SUMFILEPATH" '{ print " *" sumfilepath }') \
              <(sed -E 's|^[^ ]+ .\.(\/.*)|\1|' "$sumfile") >> "$OFTMP"

done < <(find -type f -wholename '*/all.sha1')

echo "Done, make output unique"
sort -u "$OFTMP" > "$OF"
rm "$OFTMP"

echo
echo "========================================================================="
echo "All done."
echo "  Output file:                $OF"
echo "  Input checksum file count:  $SUMFILECT"
echo "  Total input checksum count: $SUMLINECT"
echo "========================================================================="
echo
echo
