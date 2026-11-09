#! /bin/bash

BASE=trixie
CODENAME=

[ "$1" ] && BASE="$1"

case $2 in
  old)
    CODENAME=-old
    ;;

  testing)
    CODENAME=-testing
    ;;

  *)
    ;;
esac

#curl -s https://deb.kosmos-pi.org/$BASE/dists/$BASE$CODENAME/main/binary-arm64/Packages | egrep 'Package|Version' | awk -F': ' '{ print $2 }'
echo https://deb.kosmos-pi.org/$BASE/dists/$BASE$CODENAME
curl -s https://deb.kosmos-pi.org/$BASE/dists/$BASE$CODENAME/main/binary-arm64/Packages | while IFS=':' read -r key val; do
  case $key in
    Package)
      echo -n "$val => "
      ;;
    Version)
      echo $val
      ;;
  esac
done
