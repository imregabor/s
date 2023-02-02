#!/bin/bash
#
# Write smart info of the disk 
#
# Note that device identification is broken for various cases
#


#see https://stackoverflow.com/questions/18215973/how-to-check-if-running-as-root-in-a-bash-script
if [ "$EUID" -ne 0 ]; then
  echo "Error! Must run as root, exiting"
  exit -1
fi


FILENAME='./smart-'$(date -Is)'.txt'
FMO=$(findmnt -fn .)
PART=$(echo "$FMO" | cut -d' ' -f2)
DEV=$(echo "$PART" | sed -e "s/^\(.*\/sd.\)./\1/")

echo "Write SMART info to: ${FILENAME}"
echo "Findmnt info:        ${FMO}"
echo "Partition:           ${PART}"
echo "Device:              ${DEV}"

smartctl -a "$DEV" > "${FILENAME}"

echo "done."