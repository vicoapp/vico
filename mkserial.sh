#!/bin/sh

real_pubkey=$(cat ec-public.pem)
fake_pubkey=$(cat ec-public-fake.pem)

(echo 'const char *xor_key ='
dd if=/dev/random bs=1 count=150 2>/dev/null |
	od -t x1 -v |
	sed -e 's/^[0-9a-f]\{1,\} *//' \
	    -e 's/  \([0-9a-f]\{2\}\)/\\x\1/g' \
	    -e 's/ *$//' \
	    -e '/^$/d' \
	    -e 's/^/"\\x/' \
	    -e 's/$/"/' |
	sed -e '$! {s/$/ \\/;}' \
	    -e '$  {s/$/;/;}'
) > xor.c

cc -Os -pipe    mkserial.c  -o mkserial

(echo 'const char *fake_pubkey ='
echo "$fake_pubkey" |
	sed -e 's/^/"/' \
	    -e '$! {s/$/\\n" \\/;}' \
	    -e '$  {s/$/";/;}'

cat <<EOF

/* This is the real public key, but xor'ed with the fake one above.
 * Security by obscurity.
 */
const char *real_pubkey =
EOF

./mkserial "$real_pubkey" "$fake_pubkey" |
	od -t x1 -v |
	sed -e 's/^[0-9a-f]\{1,\} *//' \
	    -e 's/  \([0-9a-f]\{2\}\)/\\x\1/g' \
	    -e 's/ *$//' \
	    -e '/^$/d' \
	    -e 's/^/"\\x/' \
	    -e 's/$/"/' |
	sed -e '$! {s/$/ \\/;}' \
	    -e '$  {s/$/;/;}'
) > key.c

cc -DTEST -Os -pipe  b32.c serial.c  -o serial -lcrypto
strip serial
cc -Os -pipe mklicense.c b32.c -o mklicense -lcrypto

