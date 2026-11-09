# Shared helpers: source this file, do not run it.
KOSMOS_SCRIPTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DATAFILE="$KOSMOS_SCRIPTS_DIR/packages.tsv"

run() { echo "+ $*" >&2; "$@"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# lookup_package <name>: sets AUTHOR_URL and AUTHOR_BRANCH from packages.tsv
lookup_package() {
	local name=$1 n url branch
	AUTHOR_URL=""; AUTHOR_BRANCH=""
	while IFS=$'\t' read -r n url branch; do
		case "$n" in ''|'#'*) continue ;; esac
		if [ "$n" = "$name" ]; then AUTHOR_URL=$url; AUTHOR_BRANCH=$branch; break; fi
	done < "$DATAFILE"
	[ -n "$AUTHOR_URL" ] && [ -n "$AUTHOR_BRANCH" ] \
		|| die "Package '$name' missing or incomplete in $DATAFILE"
}
