#! /bin/bash

set -e

if [ ! -f debian/control ]; then
  echo "Run $( basename $0 ) again from inside the package root folder."
  exit 1
fi

PKG=$( cat debian/control | grep 'Source:' | awk -F': ' '{ print $2 }' )

# Remove fake metapackage with all package deps
# and autoremove unneeded packages.'
echo "Removing deps package '$PKG-build-deps'."
sudo apt purge -q -y $PKG-build-deps
echo "Removing unneeded packages."
sudo apt autoremove -q -y
echo

