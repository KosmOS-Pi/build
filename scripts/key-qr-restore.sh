#!/bin/bash
# Rebuild the armored secret key from QR code images and/or text parts, and import it.
# Usage: key-qr-restore.sh [-o output.asc] [-f expected-primary-fingerprint] <file>...
#   Each file is an image of one QR code (png/jpg) or a text file with one part
#   (first line "KOSMOS-QR i/n"). Order does not matter, all parts are needed.
#   -o  only write the reassembled armored key to this file, do not import.
#   -f  stop if the primary fingerprint is not this one.
#   Use GNUPGHOME to choose the target keyring (default: ~/.gnupg).
# NOT TESTED: try it first with a scratch GNUPGHOME.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

outfile=""; expected=""
while getopts "o:f:" opt; do
	case $opt in
		o) outfile=$OPTARG ;;
		f) expected=$OPTARG ;;
		*) die "Usage: $0 [-o output.asc] [-f expected-primary-fingerprint] <file>..." ;;
	esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || die "Usage: $0 [-o output.asc] [-f expected-primary-fingerprint] <file>..."
command -v gpg >/dev/null || die "Missing command: gpg"

umask 077
work=$(mktemp -d /dev/shm/key-qr-restore.XXXXXX)
trap 'rm -rf "$work"' EXIT

total=""
for f in "$@"; do
	[ -f "$f" ] || die "$f not found"
	case "$f" in
		*.png|*.jpg|*.jpeg|*.PNG|*.JPG|*.JPEG)
			command -v zbarimg >/dev/null || die "Missing command: zbarimg"
			zbarimg --raw -q "$f" > "$work/in.txt" || die "Cannot decode a QR code in $f"
			;;
		*)
			cp "$f" "$work/in.txt"
			;;
	esac
	header=$(head -n 1 "$work/in.txt" | tr -d '\r')
	[[ "$header" =~ ^KOSMOS-QR\ ([0-9]+)/([0-9]+)$ ]] \
		|| die "$f: first line is not a 'KOSMOS-QR i/n' header (got: $header)"
	idx=${BASH_REMATCH[1]}; n=${BASH_REMATCH[2]}
	if [ -n "$total" ] && [ "$total" != "$n" ]; then
		die "$f: says $n parts, previous files say $total (mixed backups?)"
	fi
	total=$n
	[ ! -e "$work/part.$idx" ] || die "$f: part $idx/$n given twice"
	tail -n +2 "$work/in.txt" | tr -d '\r' > "$work/part.$idx"
done

missing=""
for i in $(seq 1 "$total"); do
	[ -e "$work/part.$i" ] || missing="$missing $i"
done
[ -z "$missing" ] || die "Missing parts:$missing (of $total)"

for i in $(seq 1 "$total"); do cat "$work/part.$i"; done > "$work/secret.asc"
echo "Reassembled $total parts"

if [ -n "$outfile" ]; then
	cp "$work/secret.asc" "$outfile"
	echo "Written to $outfile (not imported)"
	exit 0
fi

fpr=$(gpg --show-keys --with-colons "$work/secret.asc" | awk -F: '$1=="fpr"{print $10; exit}')
[ -n "$fpr" ] || die "No key found in the reassembled text (typing errors?)"
echo "Primary key fingerprint: $fpr"
if [ -n "$expected" ] && [ "$expected" != "$fpr" ]; then
	die "Fingerprint mismatch: expected $expected"
fi

gpg --import "$work/secret.asc"
shred -u "$work/secret.asc"

echo
gpg --list-secret-keys --keyid-format long --with-subkey-fingerprints "$fpr"
echo
echo "Check the passphrase (it must be requested, and the signature must be good):"
echo "  echo test | gpg --local-user ${fpr}! --clearsign"
