#!/usr/bin/env python3
#
# Find candidate directories for checksum calculation, report multiple coverage.
#
# Note that checksum contents (if all paths are covered) are not considered, just
# the presence of the checksum file in the tree.

import os
import argparse
import time
import threading

visited_dirs = 0
found_count = 0
current_path = ''
running = True

def stats_logger(interval=1):
  while running:
    time.sleep(interval)
    print(f'Visited {visited_dirs} dirs, found {found_count} checksum files, currently at {current_path}')


def visit_dir(dir_path, filename, coverage_count=0, is_root=True, ignore_root=False, uncovered_need_report=True, no_multi_coverage=False):
  global visited_dirs, current_path, found_count

  current_path = dir_path
  visited_dirs += 1

  checksum_file_path=os.path.join(dir_path, filename)
  found = os.path.isfile(checksum_file_path)
  found_covered_ret = found
  found_file_ret = False

  if found:
    found_count += 1

    if is_root and ignore_root:
      print(f'Checksum found in search root, will be ignored from multiple coverage report {checksum_file_path}')
    elif no_multi_coverage:
      # not-ignored checksum file, no multiple coverage requested, can stop descending
      return False, False

    if not (is_root and ignore_root):
      uncovered_need_report=True
      coverage_count += 1

  if found and coverage_count > 1:
    print(f'Multiple ({coverage_count} x) coverage for directory {dir_path}')

  if (not found) and uncovered_need_report and (coverage_count == 0):
    print(f'Uncovered directory [ ] {dir_path}')
    if is_root and ignore_root:
      print('  This is the search root, will not count in multiple coverage')
    else:
      uncovered_need_report=False

  try:
    with os.scandir(dir_path) as dir_entries:
      uncovered_subdirs = []
      uncovered_files = []

      for entry in dir_entries:
        if entry.is_dir(follow_symlinks=False):
          found_covered, found_file = visit_dir(entry.path, filename, coverage_count, is_root=False, ignore_root=ignore_root, uncovered_need_report=uncovered_need_report, no_multi_coverage=no_multi_coverage)
          found_covered_ret = found_covered_ret or found_covered
          found_file_ret = found_file_ret or found_file

          if (coverage_count == 0) and (not found_covered) and found_file:
            uncovered_subdirs.append(entry.path)

        if entry.is_file():
          found_file_ret = True
          if coverage_count == 0:
            uncovered_files.append(entry.path)


      if found_covered_ret:
        for dir_path in uncovered_subdirs:
          print(f'Uncovered directory [*] {dir_path}')
        for file_path in uncovered_files:
          print(f'Uncovered file:         {file_path}')

  except PermissionError as e:
    print(f'PermissionError at: {dir_path}: {e}')

  return found_covered_ret, found_file_ret


def main():
  parser = argparse.ArgumentParser(
    description='Find directories with multiple occurrences of a file in their ancestry.'
  )

  parser.add_argument(
    'directory', nargs='?', default=os.getcwd(), help=f'Root directory to start traversal (default: current working directory {os.getcwd()}).'
  )

  parser.add_argument(
    '-f', '--filename', default='all.sha1',
    help='Checksum file (default: all.sha1)'
  )

  parser.add_argument(
    '-i', '--ignore-root', action='store_true',
    help='Ignore checksum in traversal root for its coverage. Will be counted as found checksum. No multi coverage report traversal will not stop on checksum in root when this option is set.'
  )

  parser.add_argument(
    '-n', '--no-multi-coverage', action='store_true',
    help='Do not report multiple coverage, stop traversing on the first not-ignored checksum.'
  )

  args = parser.parse_args()

  print(f'Starting scan from: {args.directory}')
  print(f'Looking for: {args.filename} (ignore root: {args.ignore_root})')
  print()

  logger_thread = threading.Thread(target=stats_logger, daemon=True)
  logger_thread.start()

  start_time = time.time()

  try:
    visit_dir(
      dir_path=args.directory,
      filename=args.filename,
      ignore_root=args.ignore_root,
      no_multi_coverage=args.no_multi_coverage
    )
  finally:
    global running
    running = False
    duration = time.time() - start_time
    print()
    print()
    print('Traversal completed.')
    print()
    print(f'Total visited directories: {visited_dirs}')
    print(f'Total found checksums:     {found_count}')
    print(f'Duration:                  {duration:.2f} s')
    print()

if __name__ == '__main__':
  main()
