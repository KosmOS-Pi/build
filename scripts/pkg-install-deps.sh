#! /bin/bash

if [ ! -f debian/control ]; then
  echo "Run $( basename $0 ) again from inside the package root folder."
  exit 1
fi

sudo apt-get build-dep .


