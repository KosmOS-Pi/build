#!/bin/bash
# Clone KosmOS-Pi/dpkg-<name>, add the 'author' remote, create local upstream/latest.
# Usage: pkg-clone.sh <source-package>   (ex. pkg-clone.sh libindi)
# NOT TESTED: try it in a scratch directory first.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib-pkg.sh"

GIT_BASE="${KOSMOS_GIT_BASE:-https://github.com/KosmOS-Pi}"

[ $# -eq 1 ] || die "Usage: $0 <source-package>"
name=$1
KOSMOS_PKG=no
if [ "${name::7}" = "kosmos-" ]; then
  KOSMOS_PKG=yes
else
  lookup_package "$name"
fi

dir="dpkg-$name"
[ ! -e "$dir" ] || die "$dir already exists here"

run git clone "$GIT_BASE/$dir.git" "$dir"
cd "$dir"

if [ "$KOSMOS_PKG" = "no" ]; then
  # Author tags stay local: never push with --tags
  run git remote add author "$AUTHOR_URL"
  run git fetch author --tags

  git show-ref --verify --quiet "refs/remotes/author/$AUTHOR_BRANCH" \
  	|| echo "WARNING: author has no branch '$AUTHOR_BRANCH': check packages.tsv" >&2

  if git show-ref --verify --quiet refs/remotes/origin/upstream/latest; then
	run git branch --track upstream/latest origin/upstream/latest
  else
	echo "Note: origin has no upstream/latest yet" >&2
  fi
fi

git branch -vv
