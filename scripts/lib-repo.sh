
BASE="trixie"
WITH_POOL=no

source ftp.conf.sh

if [ "$1" = "--with-pool" ]; then
  WITH_POOL=yes
elif [ "$1" = "--help" ]; then
  echo "USAGE: $0 [BASE] [--with-pool]"
  echo "   BASE remote path to sync with. Default: $BASE"
  echo "   --with-pool sync also packages .deb. Default: disabled."
  echo
  exit 0
elif [ "$1" ]; then
  BASE="$1"
fi

[ "$2" = "--with-pool" ] && WITH_POOL=yes || true

