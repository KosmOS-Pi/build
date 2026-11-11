#!/bin/bash
# Paper backup of the KosmOS primary key and subkeys with paperkey (text + QR).
# Usage: key-paper-backup.sh <primary-fingerprint> [output-dir]
# Honors GNUPGHOME. Output dir defaults to /dev/shm/key-paper-<fingerprint>.
# NOT TESTED: try it first with a scratch key and a scratch GNUPGHOME.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
die() { echo "ERROR: $*" >&2; exit 1; }

[ $# -ge 1 ] && [ $# -le 2 ] || die "Usage: $0 <primary-fingerprint> [output-dir]"
fpr=$1
out=${2:-/dev/shm/key-paper-$fpr}
[[ "$fpr" =~ ^[0-9A-F]{40}$ ]] || die "Fingerprint must be 40 uppercase hex chars, no spaces"
for c in gpg paperkey qrencode zbarimg; do
	command -v "$c" >/dev/null || die "Missing command: $c"
done
[ -x "$here/key-paper-restore.sh" ] || die "key-paper-restore.sh not found or not executable in $here"
[ ! -e "$out" ] || die "$out already exists"

# The primary key must be really present (sec, not sec#)
gpg --list-secret-keys --with-colons "$fpr" | grep -q '^sec:' \
	|| die "Primary secret key $fpr not found in this keyring (stub or missing)"

umask 077
mkdir -p "$out"
tmp=$(mktemp -d /dev/shm/key-paper-check.XXXXXX)
cleanup() {
	GNUPGHOME="$tmp" gpgconf --kill gpg-agent 2>/dev/null || true
	rm -rf "$tmp"
	[ -f "$out/secret.gpg" ] && shred -u "$out/secret.gpg" || true
}
trap cleanup EXIT

echo "Exporting keys (the passphrase will be requested)..."
gpg --export "$fpr" > "$out/public.pgp"
gpg --export-secret-keys "$fpr" > "$out/secret.gpg"
paperkey --secret-key "$out/secret.gpg" --output-type base16 --output "$out/body.txt"
shred -u "$out/secret.gpg"

# Printable text: human header (comments) + paperkey body
{
	echo "# KosmOS paper backup - $(date -u +%F)"
	echo "# Primary key fingerprint: $fpr"
	echo "# Keys in this backup (primary + subkeys):"
	gpg --list-secret-keys --keyid-format long --with-subkey-fingerprints "$fpr" | sed 's/^/#   /'
	echo "# Restore: key-paper-restore.sh <this file or QR image> <public.pgp>"
	echo "# The passphrase is NOT in this sheet: keep it somewhere else."
	echo
	cat "$out/body.txt"
} > "$out/paper.txt"

# QR code: body only, highest error correction that fits
qr_level=""
for lvl in H Q M; do
	if qrencode -l "$lvl" -s 6 -m 4 -r "$out/body.txt" -o "$out/paper-qr.png" 2>/dev/null; then
		qr_level=$lvl
		break
	fi
done
[ -n "$qr_level" ] || die "Body too large even for a single QR level M: use more QR codes"
echo "QR created with error correction level $qr_level"

# Check 1: the QR decodes to the same text
zbarimg --raw -q "$out/paper-qr.png" | diff -B - "$out/body.txt" >/dev/null \
	|| die "QR decoded content differs from the text"
echo "OK: QR decodes to the same text"

# Check 2: restore in a scratch keyring and compare fingerprints
chmod 700 "$tmp"
GNUPGHOME="$tmp" "$here/key-paper-restore.sh" "$out/paper.txt" "$out/public.pgp" "$fpr" >/dev/null
fp_list() { awk -F: '$1=="fpr"{print $10}' | sort; }
orig=$(gpg --list-secret-keys --with-colons --with-subkey-fingerprints "$fpr" | fp_list)
rest=$(GNUPGHOME="$tmp" gpg --list-secret-keys --with-colons --with-subkey-fingerprints | fp_list)
[ "$orig" = "$rest" ] || die "Restored fingerprints differ from the original"
echo "OK: restored keyring has the same fingerprints:"
echo "$orig"

echo
echo "Files in $out:"
echo "  paper.txt     print this (monospace font)"
echo "  paper-qr.png  print this too"
echo "  public.pgp    keep with the paper (or use the published keyring)"
echo "Not checked here: the passphrase on the restored key (see key-paper-restore.sh)."
echo "When printed, remove everything with: shred -u $out/* && rmdir $out"
