#! /bin/bash

if [ $# -lt 2 ]; then
  echo "ERROR: missing arguments."
  echo "USAGE: $0 grater_version lesser_version"
  exit 1
fi

if dpkg --compare-versions $1 gt $2; then
  echo OK
  echo "$1 is greater than $2"
else
  echo KO
  echo "$2 is greater than $1"
fi



