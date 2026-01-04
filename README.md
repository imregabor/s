Random scripts
==============

Use at your own risk.

Checksum manipulation
---------------------

### `calc-all-sha1.sh`

Write `all.sha1` in the working directory for all files. When an argument is given `cd` into that directory
for the traversal (output is written into the original working directory, paths will be relative to the specified
dir.) Fails if checksum or intermediate scratch file is already present.

### `continue-all-sha1.sh`

Finish an interrupted `calc-all-sha1.sh` run / extend an already calculated `all.sha1` with freshly added files.
Fails when bot an `all.sha1` and an intermediate scratch file `all.sha1-inprogress` are present. Wont recognize/remove
already present checksums (from already existing `all.sha1` / `all.sha1-inprogress` files) for files no longer present.

### `subdirs-check-for-allsha.sh`

Check for the presence of `all.sha1` files in immediate subdirectories. Calculates and prints the size of directories
where `all.sha1` is not present. Contents/coverage of the checksum file is not checked.

### `check-sha1-format.sh`

Check for formatting errors and duplicated paths in a single checksum file or for `all.sha1` searched recursively from
a directory. Note that check can flag special but valid outputs (when a referenced file name contains backslash,
newline or carriage return characters), see source for details. To search for such offending files use

```
LC_ALL=C find \( -name '*\\*' -o -name \*$'\n'\* -o -name \*$'\r'\* \)
```




Listing
-------


### `write-full-file-list.sh`

Write various deep listings from the current directory, useful for offline metadata processing/data inventory.
When an empty file matching glob `___*___*___` is present it will be treated as `<DISK ID>`, the listings will be
written into `./___listings___/<DISK_ID>/`

