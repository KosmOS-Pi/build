#!/bin/bash
# Move upstream/latest to an author's release and merge it into debian/latest,
# keeping debian/ exactly as it was before the merge. Does NOT push.
#
# Usage: pkg-update-upstream.sh <source-package> [author-ref] [version]
#   author-ref  author's tag (ex. v2.2.6) or branch as author/<branch>
#               (default: author/<branch> from packages.tsv)
#   version     upstream version for the tag upstream/<version>
#               (default: derived from a tag name by dropping the leading non-digits)
#
# Run from dpkg-<name> or from its parent directory.
# NOT TESTED: try it on a scratch clone first.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ $# -ge 1 ] && [ $# -le 3 ] || die "Usage: $0 <source-package> [author-ref] [version]"
name=$1; ref=${2:-}; version=${3:-}

if [ -d "dpkg-$name/.git" ]; then
	cd "dpkg-$name"
elif [ "$(basename "$PWD")" = "dpkg-$name" ] && [ -d .git ]; then
	:
else
	die "Run this from dpkg-$name or from its parent directory"
fi

lookup_package "$name"

# --- Preconditions ---------------------------------------------------------
[ -z "$(git status --porcelain)" ] || die "Working tree not clean"
[ ! -e "$(git rev-parse --git-path MERGE_HEAD)" ] || die "A merge is already in progress"
git remote get-url author >/dev/null 2>&1 || die "No 'author' remote: run pkg-clone.sh first"

# --- Sync with origin (you may have pushed from another machine) -----------
sync_branch() {
	local b=$1
	git show-ref --verify --quiet "refs/heads/$b" || die "Local branch $b is missing"
	if git rev-parse --verify -q "${b}@{u}" >/dev/null; then
		run git checkout -q "$b"
		run git merge --ff-only -q "@{u}"
	else
		echo "WARNING: $b has no upstream tracking: not synced with origin" >&2
	fi
}
run git fetch origin
run git fetch author --tags
sync_branch upstream/latest
sync_branch debian/latest

# --- Resolve what to bring in ----------------------------------------------
target=${ref:-author/$AUTHOR_BRANCH}
commit=$(git rev-parse --verify -q "$target^{commit}") \
	|| die "'$target' not found (branches must be written author/<branch>)"

if [ -z "$version" ] && git show-ref --verify --quiet "refs/tags/$target"; then
	version=$(printf '%s' "$target" | sed -E 's/^[^0-9]*//')
fi
if [ -n "$version" ] && ! [[ "$version" =~ ^[0-9][0-9A-Za-z._+-]*$ ]]; then
	die "Version '$version' is not usable in a tag name: pass it as third argument (use _ instead of ~)"
fi
if [ -z "$version" ]; then
	echo "NOTE: $target is not a tag: no upstream/<version> tag will be created" >&2
elif git rev-parse -q --verify "refs/tags/upstream/$version" >/dev/null; then
	[ "$(git rev-parse "refs/tags/upstream/$version^{commit}")" = "$commit" ] \
		|| die "Tag upstream/$version already exists on a different commit"
fi

# --- 1. upstream/latest: fast-forward only, then tag -----------------------
old=$(git rev-parse upstream/latest)
run git checkout -q upstream/latest
run git merge --ff-only -q "$commit" \
	|| die "$target is not a descendant of upstream/latest (going back, or history rewritten by the author?)"
if [ -n "$version" ] && ! git rev-parse -q --verify "refs/tags/upstream/$version" >/dev/null; then
	run git tag "upstream/$version" "$commit"
fi

# Informational: what the author changed in its own debian/ (new build dependencies?)
if git cat-file -e "$commit:debian" 2>/dev/null; then
	echo "Upstream ships a debian/ directory: it will NOT be merged, debian/latest keeps its own."
	if git cat-file -e "$old:debian" 2>/dev/null; then
		echo "Changes to the author's debian/ since the previous upstream/latest:"
		git --no-pager diff --stat "$old" "$commit" -- debian || true
		echo "(details: git diff $old $commit -- debian)"
	fi
fi

# --- 2. Merge into debian/latest, restoring debian/ --------------------------
run git checkout -q debian/latest
if git merge-base --is-ancestor upstream/latest HEAD; then
	echo "debian/latest already contains upstream/latest: nothing to merge."
	exit 0
fi
git cat-file -e HEAD:debian 2>/dev/null || die "debian/latest has no debian/ directory"

echo "+ git merge --no-commit --no-ff upstream/latest" >&2
git merge --no-commit --no-ff upstream/latest || true   # conflicts on debian/ are expected
git rev-parse -q --verify MERGE_HEAD >/dev/null || die "The merge did not start: see messages above"

# The rule: debian/ ends up exactly as it was before the merge
run git rm -rf -q --ignore-unmatch debian
run git checkout HEAD -- debian
git diff --cached --quiet HEAD -- debian \
	|| die "debian/ differs from HEAD after the restore (unexpected): merge left in progress"

unmerged=$(git diff --name-only --diff-filter=U)
if [ -n "$unmerged" ]; then
	echo "Conflicts OUTSIDE debian/, to resolve by hand, then 'git commit':" >&2
	echo "$unmerged" >&2
	exit 1
fi

if [ -n "$version" ]; then
	label="upstream/$version"
else
	label="upstream/latest ($(git rev-parse --short "$commit"))"
fi
run git commit -q -m "Merge $label into debian/latest"

echo
echo "Done. Next steps:"
echo "  1. update debian/changelog (new version: ${version:-<version>}+kosmos-1~deb13, plus epoch if the package has one)"
echo "  2. review: git log --oneline -3 && git show --stat HEAD"
echo "  3. push with explicit refs, never --tags:"
echo "       git push origin upstream/latest ${version:+upstream/$version }debian/latest"
