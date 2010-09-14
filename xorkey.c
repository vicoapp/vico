#include <err.h>
#include <stdio.h>
#include <string.h>

#define PUBKEY_LEN 149

#include "xor.c"

int
main(int argc, char **argv)
{
	extern const char	*__progname;
	const char		*real_pubkey;
	const char		*fake_pubkey;
	int			 i;

	if (argc != 3)
		errx(1, "syntax: %s real-pubkey fake-pubkey", __progname);

	real_pubkey = argv[1];
	fake_pubkey = argv[2];

	fprintf(stderr, "real pubkey = [%s]\n", real_pubkey);
	fprintf(stderr, "fake pubkey = [%s]\n", fake_pubkey);

	if (strlen(real_pubkey) != strlen(fake_pubkey))
		errx(2, "real key length differs from fake key length");

	if (strlen(real_pubkey) != PUBKEY_LEN)
		errx(2, "key length %d != %d", strlen(real_pubkey), PUBKEY_LEN);

	for (i = 0; i < strlen(real_pubkey); i++)
		printf("%c", (real_pubkey[i] ^ xor_key[i]) ^ fake_pubkey[i]);

	return 0;
}

