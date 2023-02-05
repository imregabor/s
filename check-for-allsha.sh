#!/bin/bash

while read line ; do
  STAT="?"
  if [ -f "${line}/all.sha1" ] ; then
    STAT="OK           "
  elif [ -f "${line}/all.sha1-inprogress" ] ; then
    STAT="IN PROGRESS  "
  else
    STAT="** MISSING **"
  fi

  echo "$STAT $line"


done < <( find -type d -maxdepth 1 -mindepth 1)