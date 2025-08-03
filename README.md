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


Listing
-------


### `write-full-file-list.sh`

Write various deep listings from the current directory, useful for offline metadata processing/data inventory.
When an empty file matching glob `___*___*___` is present it will be treated as `<DISK ID>`, the listings will be
written into `./___listings___/<DISK_ID>/`

