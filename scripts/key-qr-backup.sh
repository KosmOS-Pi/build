#!/bin/bash
# Paper backup of the KosmOS primary key and subkeys: armored export split in several QR codes.
# Usage: key-qr-backup.sh <primary-fingerprint> [output-dir]
# Honors GNUPGHOME. Output dir defaults to /dev/shm/key-qr-<fingerprint>.
# Env: LINES_PER_QR (default 10) = armored lines in each QR code.
# NOT TESTED: try it first with a scratch key and a scratch GNUPGHOME.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
die() { echo "ERROR: $*" >&2; exit 1; }

[ $# -ge 1 ] && [ $# -le 2 ] || die "Usage: $0 <primary-fingerprint> [output-dir]"
fpr=$1
out=${2:-/dev/shm/key-qr-$fpr}
lines=${LINES_PER_QR:-10}
[[ "$fpr" =~ ^[0-9A-F]{40}$ ]] || die "Fingerprint must be 40 uppercase hex chars, no spaces"
[[ "$lines" =~ ^[0-9]+$ ]] && [ "$lines" -gt 0 ] || die "LINES_PER_QR must be a positive number"
for c in gpg qrencode zbarimg split; do
	command -v "$c" >/dev/null || die "Missing command: $c"
done
[ -x "$here/key-qr-restore.sh" ] || die "key-qr-restore.sh not found or not executable in $here"
[ ! -e "$out" ] || die "$out already exists"

# The primary key must be really present (sec, not sec#)
gpg --list-secret-keys --with-colons "$fpr" | grep -q '^sec:' \
	|| die "Primary secret key $fpr not found in this keyring (stub or missing)"

umask 077
mkdir -p "$out"
tmp=$(mktemp -d /dev/shm/key-qr-work.XXXXXX)
cleanup() {
	GNUPGHOME="$tmp/gnupg" gpgconf --kill gpg-agent 2>/dev/null || true
	rm -rf "$tmp"
}
trap cleanup EXIT

echo "Exporting keys (the passphrase will be requested)..."
gpg --armor --export "$fpr" > "$out/public.asc"
gpg --armor --export-secret-keys "$fpr" > "$out/secret-armored.asc"

# Split by whole lines, then one QR code for each part
split -l "$lines" -d -a 3 "$out/secret-armored.asc" "$tmp/part."
parts=("$tmp"/part.*)
n=${#parts[@]}
echo "Armored export split in $n parts of up to $lines lines"

i=0
for p in "${parts[@]}"; do
	i=$((i + 1))
	name=$(printf 'qr-%02d-of-%02d.png' "$i" "$n")
	# Command substitution drops the trailing newline: the decoder adds it back
	data=$(printf 'KOSMOS-QR %d/%d\n' "$i" "$n"; cat "$p")
	printf '%s' "$data" | qrencode -l H -s 6 -m 4 -o "$out/$name" \
		|| die "Part $i too large for a QR code at level H: lower LINES_PER_QR"
done
echo "Created $n QR images"

# Check 1: the QR codes decode and reassemble to the exact export
images=("$out"/qr-*.png)
"$here/key-qr-restore.sh" -o "$tmp/reassembled.asc" "${images[@]}" >/dev/null
cmp "$tmp/reassembled.asc" "$out/secret-armored.asc" \
	|| die "Reassembled text differs from the export"
echo "OK: QR codes reassemble to the exact export"

# Check 2: restore in a scratch keyring and compare fingerprints
mkdir -m 700 "$tmp/gnupg"
GNUPGHOME="$tmp/gnupg" "$here/key-qr-restore.sh" -f "$fpr" "${images[@]}" >/dev/null
fp_list() { awk -F: '$1=="fpr"{print $10}' | sort; }
orig=$(gpg --list-secret-keys --with-colons --with-subkey-fingerprints "$fpr" | fp_list)
rest=$(GNUPGHOME="$tmp/gnupg" gpg --list-secret-keys --with-colons --with-subkey-fingerprints | fp_list)
[ "$orig" = "$rest" ] || die "Restored fingerprints differ from the original"
echo "OK: restored keyring has the same fingerprints:"
echo "$orig"

echo
echo "Files in $out:"
echo "  qr-NN-of-$(printf '%02d' "$n").png   print all of them (keep the order on the sheet)"
echo "  secret-armored.asc   the same content as text: print it too (monospace font)"
echo "  public.asc           public key, optional"
echo "The passphrase is NOT in these files: keep it somewhere else."
echo "Not checked here: the passphrase on the restored key (see key-qr-restore.sh)."
echo "When printed, remove everything with: shred -u $out/* && rmdir $out"
