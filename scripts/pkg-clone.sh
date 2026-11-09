#!/bin/bash
# Clone KosmOS-Pi/dpkg-<name>, add the 'author' remote, create local upstream/latest.
# Usage: pkg-clone.sh <source-package>   (ex. pkg-clone.sh libindi)
# NOT TESTED: try it in a scratch directory first.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib-pkg.sh"

GIT_BASE="${KOSMOS_GIT_BASE:-https://github.com/KosmOS-Pi}"

[ $# -eq 1 ] || die "Usage: $0 <source-package>"
name=$1
lookup_package "$name"

dir="dpkg-$name"
[ ! -e "$dir" ] || die "$dir already exists here"

run git clone "$GIT_BASE/$dir.git" "$dir"
cd "$dir"

# Author tags stay local: never push with --tags
run git remote add author "$AUTHOR_URL"
run git fetch author --tags

if git show-ref --verify --quiet refs/remotes/origin/upstream/latest; then
	run git branch --track upstream/latest origin/upstream/latest
else
	echo "Note: origin has no upstream/latest yet" >&2
fi

git show-ref --verify --quiet "refs/remotes/author/$AUTHOR_BRANCH" \
	|| echo "WARNING: author has no branch '$AUTHOR_BRANCH': check packages.tsv" >&2

git branch -vv
