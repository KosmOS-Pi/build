#! /bin/bash

set -e

print_usage() {
  echo "USAGE: $0 check | update | edit"
}

sudo apt install cme libconfig-model-dpkg-perl

if [ ! -f debian/control ]; then
  echo "This script must be run from root of package."
  exit 1
fi

if [ -z "$1" ]; then
  echo "ERROR: missing command argument."
  print_usage
fi

case $1 in
  check)
    cme check dpkg-copyright
    ;;
  update)
    cme update dpkg-copyright
    ;;
  edit)
    cme edit dpkg-copyright
    ;;
  *)
    echo "ERROR: unknown command '$1"
    print_usage
    ;;
esac

