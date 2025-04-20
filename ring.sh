#!/bin/sh
#
# Ring the terminal bell continuosly
#
# See https://superuser.com/questions/806511/how-can-i-ring-the-audio-bell-within-a-bash-script-running-under-gnu-screen

while : ; do
  echo
  echo
  echo
  echo "**********************"
  echo "Ring"
  echo "**********************"
  echo
  echo
  echo
  
  tput bel
  sleep 1
done
