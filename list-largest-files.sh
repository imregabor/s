#!/bin/bash
#
# Find the list of 100 largest files
#
echo
echo
comm -23 <(du --apparent-size -ab | sort) <(du --apparent-size -b | sort) | sort -nr | head -100
echo
echo