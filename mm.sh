#!/bin/bash
#
# Collect system level infos
#
# Usage
#  mm.sh [-ipmi] [<COLLECTROOT>]
#

DOIPMI=false
BD=$(readlink -m .)

while [ $# -gt 0 ]; do
  case "$1" in
    -ipmi)
      DOIPMI=true
      shift
      ;;
    *)
      BD=$(readlink -m "$1")
      shift
      ;;
  esac
done



H=$(hostname)

TS2=$(date -Iseconds)
TS1=$(date -I -d "$TS2")



OD="${BD}/${H}/${TS1}/${TS2}"

echo "[mm] OD: 	\"$OD\""

mkdir -p "$OD"
echo "$TS2" > "$OD/date.txt"

cp "$0" "$OD/"

echo "[mm] hostname"
hostname > "$OD/hostname.txt"

smartctl --scan | cut -d ' ' -f 1 | while read drv ; do
  lab=$(echo $drv | sed -e "s/.*\///")
  echo "[mm] $lab: smartctl -a $drv"
  smartctl -a "$drv" > "$OD/smart-$lab.txt"
done

echo "[mm] ifconfig"
ifconfig > "$OD/ifconfig.txt"

if "$DOIPMI" ; then
  echo "[mm] IPMI sensors"
  ipmitool sdr list > "$OD/ipmi-sensors.txt"
else
  echo "[mm] skipping IPMI sensors"
fi

echo "[mm] dmidecode"
dmidecode > "$OD/dmidecode.txt"

echo "[mm] lsblk"
lsblk -fm > "$OD/lsblk.txt"

echo "[mm] blkid"
blkid > "$OD/blkid.txt"

echo "[mm] df"
df > "$OD/df.txt"

echo "[mm] iostat"
iostat > "$OD/iostat.txt"

echo "[mm] lsusb"
lsusb > "$OD/lsusb.txt"

echo "[mm] lspci -mmv"
lspci -mmv > "$OD/lspci.txt"

echo "[mm] lscpu --extended"
lscpu --extended > "$OD/lscpu-extended.txt"

echo "[mm] mpstat -P ALL"
mpstat -P ALL > "$OD/mpstat.txt"

echo "[mm] sensors"
sensors > "$OD/sensors.txt"


