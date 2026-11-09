#! /bin/bash

set -e

source $( dirname $0 )/lib-repo.sh

echo "Preparing local dirs..."
mkdir -p $BASE/conf $BASE/dists $BASE/db

DL=''
LFTP_POOL=''

if [ "$WITH_POOL" = "yes" ]; then
  mkdir -p $BASE/pool
  DL=' (with pool)'
  LFTP_POOL="mirror --delete \"/$BASE/pool\" \"./$BASE/pool\""$'\n'
fi

echo "Downloading...$DL"

lftp -u "$USER","$PASS" $HOST << EOF
mirror --delete "/$BASE/conf" "./$BASE/conf"
mirror --delete "/$BASE/dists" "./$BASE/dists"
mirror --delete "/$BASE/db" "./$BASE/db"
${LFTP_POOL}bye
EOF

echo "Complete."
echo
