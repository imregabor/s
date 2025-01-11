#bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install jq and try again."
  exit 1
fi

usage() {
  echo
  echo "Invoke a command on all hosts"
  echo
  echo "Usage: $0 -r <JSON_FILE>"
  echo
  echo "Options:"
  echo "  -r, --read     Path to the definition JSON file."
  echo "  -H, --host     Specify a single host to run on"
  echo "  -c, --command  Command to run"
  echo "  -h, --help     Display this help message."
  echo "  -t, --timeout  SSH connect timeout, default 2."
  echo
  echo "Availeble commands:"
  echo
  echo "   mount         Invoke \"./mount-scrs.sh\" with a password read from the console"
  echo "   shutdown      Shutdown now"
  echo "   df            df -h"
  echo "   info          One liner system info"

  exit 1
}

JSON_FILE=""
COMMAND=""
TIMEOUT="2"
HOST=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--read)
      JSON_FILE=$2
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -c|--command)
      COMMAND=$2
      shift 2
      ;;
    -t|--timeout)
      TIMEOUT=$2
      shift 2
      ;;
    -H|--host)
      HOST=$2
      shift 2
      ;;
    *)
      echo "Error: Unknown option $1"
      usage
      ;;
  esac
done

if [[ ! "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] ; then
  echo "Error: Invalid timeout \"$TIMEOUT\""
  exit 1
fi

if [ -z "$COMMAND" ]; then
  echo "Error: Command is required."
  usage
fi

if [ "$COMMAND" != "mount" ] && [ "$COMMAND" != "shutdown" ] && [ "$COMMAND" != "df" ] && [ "$COMMAND" != "info" ]; then
  echo "Error: Unknown command \"$COMMAND\""
  usage
fi

if [ -z "$JSON_FILE" ]; then
  echo "Error: JSON file is required."
  usage
fi

if [ ! -f "$JSON_FILE" ]; then
  echo "Error: JSON file \"$JSON_FILE\" does not exist."
  exit 1
fi

if ! jq empty "$JSON_FILE" 2> /dev/null; then
  echo "Error: File $JSON_FILE is not a valid JSON file."
  exit 1
fi

if [ -n "$HOST" ]; then
  IP=$(jq -r --arg host "$HOST" '.[$host].ip // empty' "$JSON_FILE")
  if [ -z "$IP" ]; then
    echo
    echo "Error: No host / IP found for host \"$HOST\" in JSON file \"$JSON_FILE\"."
    exit 1
  fi
  echo "Will use IP $IP of host \"$HOST\""
  IPS=$IP
else
  IPS=$(jq -r '.[].ip' "$JSON_FILE")
  if [ -z "$IPS" ]; then
    echo
    echo "Error: No IPs found in the JSON file."
    exit 1
  fi
  echo "IPs found: $(echo $IPS | tr '\n' ' ')"
fi

PASSWORD=""
if [ "$COMMAND" == "mount" ]; then
  echo
  echo
  echo "Will invoke mount-scrs on all hosts."
  echo
  read -s -p "Enter unlock pass: " PASSWORD
  echo
fi
echo

# Iterate over each IP and execute the script
for IP in $IPS; do
  echo
  echo "=========================================================="
  echo "Running command \"$COMMAND\" on \"$IP\""
  echo "=========================================================="
  echo
  echo

  case $COMMAND in
    mount)
      echo "$PASSWORD" | ssh -o "ConnectTimeout=$TIMEOUT" "$IP" 'sudo ./mount-scrs.sh' 2>&1 | sed 's/^/[remote] /'
      ;;
    shutdown)
      ssh -o "ConnectTimeout=$TIMEOUT" "$IP" 'sudo shutdown -h now' 2>&1 | sed 's/^/[remote] /'
      ;;
    df)
      ssh -o "ConnectTimeout=$TIMEOUT" "$IP" 'df -h' 2>&1 | sed 's/^/[remote] /'
      ;;
    info)
      ssh -o "ConnectTimeout=$TIMEOUT" "$IP" 'bash -s' << 'EOF' 2>&1 | sed 's/^/[remote] /'
HOSTNAME=$(hostname)
MACHINE=$(sudo dmidecode | grep "Product Name:" | sed 's/.*Product Name://' | sed 's/^ *//; s/  */ /g; s/ *$//')
CPU=$(lscpu | grep -E 'Socket|Model name|Core|Thread' | awk -F: '/Socket/ {s=$2} /Model name/ {m=$2} /Core/ {c=$2} /Thread/ {t=$2} END {print s " x " m ", " s*c " cores, " s*c*t " threads"}' | sed 's/^ *//; s/  */ /g;s/ *$//')
OS=$(lsb_release -sd)
KERNEL=$(uname -r)
MEM=$(free -h | grep Mem | awk '{print $2 ", Available: " $7}')
DISK=$(df -h --total | grep 'total' | awk '{print $2", Used: "$3", Available: "$4}')
UPTIME=$(uptime -p)
echo "$HOSTNAME: $MACHINE | $CPU | Mem: $MEM | Disk: $DISK | $OS | $KERNEL | $UPTIME"
EOF
      ;;
    *)
      echo "Unknown command: $COMMAND"
      ;;
  esac

  echo
  echo
  echo
done

echo "=========================================================="
echo "All done."
echo "=========================================================="
echo
echo
