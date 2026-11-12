#! /bin/bash

set -e

if [ $# -lt 2 ]; then
  echo "ERROR: not enough arguments."
  echo "USAGE: $0 patch_name dest_file_path"
  echo "   - patch_name      name of resulting patch file (without .patch extension)"
  echo "   - dest_file_path  path (from here) and filename of file to patch."
  exit 1
fi

if [ ! -f debian/control ]; then
  echo "Script must be run from root of package."
  exit 1
fi

export QUILT_PATCHES=debian/patches
quilt new $1.patch
quilt add $2

echo "Now modify $2..."
read -p "...and press ENTER when done." d

quilt refresh

echo "Patch saved."
echo
