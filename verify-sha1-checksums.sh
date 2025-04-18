#!/bin/bash
#
# Verify file integrity by SHA1 checksum
#
# Detailed progress and throughput logging.
#

SHA1_FILE="${1:-all.sha1}"

if [[ "$SHA1_FILE" == "-h" || "$SHA1_FILE" == "--help" ]]; then
    echo -e "Usage: $0 [sha1_file]"
    echo "Default: ./all.sha1"
    exit 0
fi

if [[ ! -f $SHA1_FILE ]]; then
  if [[ -e $SHA1_FILE ]]; then
    # using process substitution?
    echo "SHA1 '$SHA1_FILE' exists but not a regular file, continuing"
  else
    echo "SHA1 file '$SHA1_FILE' not found!"
    exit 1
  fi
fi

# in case of process substitution we read the file once
sha1_file_content=$(cat "$SHA1_FILE")

total_files=0
error_count=0
pass_count=0
total_bytes=0
start_time=$(date +%s)
last_time=$start_time
last_bytes=0


expected_count=$(echo "$sha1_file_content" | wc -l)

human_readable_size() {
  local size="$1"

  if [[ "$size" == "?" ]]; then
    echo "? B"
    return
  fi

  local -a suffixes=("B" "KiB" "MiB" "GiB" "TiB" "PiB")
  local i=0
  local float_size="$size"
  local rounded_size="$size"

  while (( rounded_size >= 1024 && i < ${#suffixes[@]} - 1 )); do
    float_size=$(awk "BEGIN {printf \"%.2f\", $float_size/1024}")
    rounded_size=$(( rounded_size / 1024 ))
    ((i++))
  done

  echo "$float_size ${suffixes[i]}"
}

echo
echo
echo "========================================================================================================================================"
echo
echo "Check SHA1 sums from $SHA1_FILE"
echo
echo "Expected checks: $expected_count"
echo
echo "========================================================================================================================================"
echo
echo

while IFS= read -r line; do
  ((total_files++))

  sha1_output=$(echo "$line" | sha1sum -c 2>&1)
  sha1_status=$?
  sha1_output=$(echo "$sha1_output" | grep -v "^sha1sum: ")

  # Extract file name from sha1sum output
  # Format: filename: OK  OR  filename: FAILED
  file_path=$(echo "$sha1_output" | sed -e 's/:[^:]*//')


  if [[ $sha1_status -ne 0 ]]; then
    ((error_count++))
    check_result="FAIL"

    if [[ ! -f "$file_path" ]]; then
      echo "Failed file not found: $file_path"
      file_size="?"
    else
      # do not count failed size into total (might not read fully if checksum is malformed)
      file_size=$(stat -c %s "$file_path" 2>/dev/null)
    fi

  else
    ((pass_count++))

    if [[ ! -f "$file_path" ]]; then
      echo "Passed file not found: $file_path"
      # skip stat printing
      continue
    fi

    check_result="PASS"
    file_size=$(stat -c %s "$file_path" 2>/dev/null)
    ((total_bytes += file_size))

  fi

  # Timing & Bandwidth
  current_time=$(date +%s)
  elapsed=$((current_time - start_time))
  last_elapsed=$((current_time - last_time))
  last_time=$current_time

  current_bps='?'
  avg_bps='?'

  if (( last_elapsed > 0 && sha1_status == 0 )); then
      current_bps=$(( file_size / last_elapsed ))
  fi

  if (( elapsed > 0 )); then
      avg_bps=$(( total_bytes / elapsed ))
  fi

  printf "[%5d s] %5d/%d: %s (%11s, %11s/s), passed %5d, failed %d, total passed %11s %11s/s | %s\n" \
    "$elapsed" "$total_files" "$expected_count" "$check_result" \
    "$(human_readable_size "$file_size")" "$(human_readable_size "$current_bps")" \
    "$pass_count" "$error_count" \
    "$(human_readable_size "$total_bytes")" "$(human_readable_size "$avg_bps")" "$sha1_output"


done < <(echo "$sha1_file_content")

end_time=$(date +%s)
total_time=$((end_time - start_time))
if (( total_time > 0 )); then
  final_avg_bps=$(( total_bytes / total_time ))
else
  final_avg_bps='?'
fi

echo
echo
echo "========================================================================================================================================"
echo "All done:"
echo
echo "Total files checked: $total_files"
echo "Passed:              $pass_count"
echo "Failed:              $error_count"
echo "Total size:          $(human_readable_size "$total_bytes")"
echo "Total time:          ${total_time} s"
echo "Average bandwidth:   $(human_readable_size "$final_avg_bps")/s"
echo "========================================================================================================================================"
echo
echo
