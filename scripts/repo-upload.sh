#! /bin/bash

set -e

source $( dirname $0 )/lib-repo.sh

if [ "$WITH_POOL" = "yes" ]; then
  DL=' (with pool)'
  LFTP_POOL="mirror -R --only-missing \"./$BASE/pool\" \"/$BASE/pool\""$'\n'
fi


echo "Uploading...$DL"

lftp -u "$USER","$PASS" $HOST << EOF
${LFTP_POOL}mirror -R --delete "./$BASE/db" "/$BASE/db"
mirror -R --delete "./$BASE/dists" "/$BASE/dists"
bye
EOF

echo "Complete"
echo
