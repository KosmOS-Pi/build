#! /bin/bash

# Depends on cme and libconfig-model-dpkg-perl. Install with:
#   $ sudo apt install cme libconfig-model-dpkg-perl

set -e

print_usage() {
  echo "USAGE: $0 check | update | edit"
}

if [ ! -f debian/control ]; then
  echo "This script must be run from root of package."
  exit 1
fi

if [ -z "$1" ]; then
  echo "ERROR: missing command argument."
  print_usage
  exit 1
fi

case $1 in
  check|update|edit|fix)
    cme $1 dpkg-copyright
    ;;
  *)
    echo "ERROR: unknown command '$1'"
    print_usage
    exit 1
    ;;
esac

