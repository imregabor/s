#!/usr/bin/env python3
#
# Compare two checksums
#
# Print differences to get from the state represented by the first one to the second one:
#
#  + <PATH>               Content is not present in 1 only in 2 (add)
#  - <PATH>               Content is not present in 2 only in 1 (remove)
#  R <PATH1> -> <PATH2>   Content is present in both but with different paths
#  C <PATH1> -> <PATH2>   Content is present in both, on 2 appears under a new path
#
# Note that this list is not suitable for automatic consumption.
#  - Directory renames, copies and deletes are not identified, just files
#  - Directory deletes are not identified

import os
import sys
import argparse
from collections import defaultdict

def parse_checksum_file(file_path):
  cs2f = defaultdict(set)
  f2cs = {}
  with open(file_path, "r") as f:
    read_lines = 0;
    for line in f:
      line = line.removesuffix("\n")
      read_lines = read_lines + 1

      if " *" in line:
        checksum, filename = line.split(" *", 1)
      elif "  " in line:
        checksum, filename = line.split("  ", 1)
      else:
        print(f'Line {read_lines} is malformed, skipping: {line}')
        continue

      cs2f[checksum].add(filename)
      f2cs[filename] = checksum

  print(f'Read {read_lines} lines from {file_path}')
  return cs2f, f2cs

def diff(old_file, new_file):
  old_cs2f, old_f2cs = parse_checksum_file(old_file)
  new_cs2f, new_f2cs = parse_checksum_file(new_file)

  # old files which are not present in now with the same content
  # they need to be moved or removed
  affected_old_files = set()

  for old_file, old_cs in old_f2cs.items():
    if old_file in new_f2cs and old_cs in new_f2cs[old_file]:
      # same file with same content is present in both
      # we at least can use it as a copy source
      continue
    # we have to do something with this path in old
    affected_old_files.add(old_file)

  for new_file, new_cs in new_f2cs.items():
    if new_file in old_f2cs and old_f2cs[new_file] == new_cs:
      # unchanged
      continue
    # this paths is added either by addition, copy or rename
    if new_cs in old_cs2f:
      # we have a rename or copy source
      # one old file with different path, same content
      old_file = next(iter(old_cs2f[new_cs]))

      if old_file in affected_old_files:
        # we have to do something with this path in old
        # lets rename
        print(f'R {old_file} -> {new_file}')
        affected_old_files.remove(old_file)
      else:
        # this file in old should be left untouched
        print(f'C {old_file} -> {new_file}')
    else:
      # we dont have this content in old, this is a genuine add
      print(f'+ {new_file}')

  # Remaining affected old files are deleted
  for old_file in affected_old_files:
    print(f'- {old_file}')

def main():
  parser = argparse.ArgumentParser(
    description="Compare two checksum files."
  )
  parser.add_argument("from_checksum", help="Path to the first checksum file")
  parser.add_argument("to_checksum", help="Path to the second checksum file")

  args = parser.parse_args()

  if not os.path.isfile(args.from_checksum):
    print(f'From checksum not found: {args.from_checksum}')
    sys.exit(1)

  if not os.path.isfile(args.to_checksum):
    print(f'To checksum not found: {args.to_checksum}')
    sys.exit(1)

  diff(args.from_checksum, args.to_checksum)


if __name__ == "__main__":
  main()
