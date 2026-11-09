#! /bin/bash

if [ ! -f debian/control ]; then
  echo "Run $( basename $0 ) again from inside the package root folder."
  exit 1
fi

# Simple install dep packages.
#sudo apt-get build-dep .

PKG=$( cat debian/control | grep 'Source:' | awk -F': ' '{ print $2 }' )

# Generake a fake metapackage with all package deps.
# Useful to uninstall build deps after build.

# Needed packages
sudo apt-get install -y devscripts equivs build-essential fakeroot

# Produce fake meta-package here
# mk-build-deps options:
#  -i -> installs deps metapackage 
#  -r -> removes deps metapackage after installation.
#        A simple $ apt autoremove will uninstall uneeded packages.
sudo mk-build-deps -i -r -t "apt-get -y --no-install-recommends" debian/control

echo
echo "Deps installed in package '$PKG-build-dep'."
apt list $PKG-build-dep
echo
