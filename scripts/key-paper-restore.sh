#!/bin/bash
# Rebuild the secret keys from a paperkey backup and import them in GNUPGHOME.
# Usage: key-paper-restore.sh <paper.txt | qr-image> <public.pgp> [expected-primary-fingerprint]
#   The first argument can be the typed/scanned text or an image of the QR code.
#   Use GNUPGHOME to choose the target keyring (default: ~/.gnupg).
# NOT TESTED: try it first with a scratch GNUPGHOME.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

[ $# -ge 2 ] && [ $# -le 3 ] || die "Usage: $0 <paper.txt|qr-image> <public.pgp> [expected-primary-fingerprint]"
paper=$1; pub=$2; expected=${3:-}
for c in gpg paperkey; do command -v "$c" >/dev/null || die "Missing command: $c"; done
[ -f "$paper" ] || die "$paper not found"
[ -f "$pub" ] || die "$pub not found"

umask 077
work=$(mktemp -d /dev/shm/key-paper-restore.XXXXXX)
trap 'rm -rf "$work"' EXIT

case "$paper" in
	*.png|*.jpg|*.jpeg)
		command -v zbarimg >/dev/null || die "Missing command: zbarimg"
		zbarimg --raw -q "$paper" > "$work/paper.txt" || die "Cannot decode the QR code"
		paper="$work/paper.txt"
		;;
esac

pub_fpr=$(gpg --show-keys --with-colons "$pub" | awk -F: '$1=="fpr"{print $10; exit}')
[ -n "$pub_fpr" ] || die "No key found in $pub"
echo "Public key primary fingerprint: $pub_fpr"
if [ -n "$expected" ] && [ "$expected" != "$pub_fpr" ]; then
	die "Fingerprint mismatch: expected $expected"
fi

paperkey --pubring "$pub" --secrets "$paper" --input-type base16 --output "$work/secret.gpg" \
	|| die "paperkey failed: wrong public key, or typing errors in the text (check the CRC lines)"
gpg --import "$work/secret.gpg"
shred -u "$work/secret.gpg"

echo
gpg --list-secret-keys --keyid-format long --with-subkey-fingerprints "$pub_fpr"
echo
echo "Check the passphrase (it must be requested, and the signature must be good):"
echo "  echo test | gpg --local-user <FP_SUBKEY>! --clearsign   # <FP_SUBKEY>: una sottochiave [S] elencata sopra"
