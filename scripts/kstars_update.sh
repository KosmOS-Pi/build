#! /bin/bash

set -e

if [ -z "$1" ]; then
	echo "Missing version to update to!"
	exit 1
fi

git fetch author
git checkout upstream/latest
git merge --no-commit -s ours author/stable-$1
git read-tree -u --reset author/stable-$1
git commit -m "Update to upstream $1"
git tag upstream/$1

# verifica: deve stampare niente
DIFFOUT=$( git diff --stat author/stable-$1 HEAD )

if [ "$DIFFOUT" ]; then
	echo "We are not synced with stable-$1"
	echo "$DIFFOUT"
	exit 1
fi

git checkout debian/latest
git merge --no-commit -s ours upstream/latest
git read-tree -u --reset upstream/latest
git checkout HEAD -- debian
git commit -m "Merge upstream $1"

# verifica: deve stampare niente (l'unica differenza è debian/)
DIFFOUT=$( git diff --stat upstream/latest HEAD -- . ':!debian' )
if [ "$DIFFOUT" ]; then
	echo "Something gone wrong (stable-$1)"
	echo "$DIFFOUT"
	exit 1
fi

