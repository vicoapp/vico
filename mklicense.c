#include <err.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include "license.h"
#include "b32.h"

void
usage(void)
{
	extern const char	*__progname;

	printf("syntax: %s [-h] [-e email] [-n name] [-k keyfile] [-s serial]\n", __progname);
	exit(0);
}

void
hexdump(void *data, size_t len)
{
	uint8_t *p = data;

	while (len--) {
		size_t ofs = p - (uint8_t *)data;
		if (ofs % 16 == 0)
			fprintf(stderr, "%s%04lx:", ofs == 0 ? "" : "\n", ofs);
		else if (ofs % 8 == 0)
			fprintf(stderr, " ");
		fprintf(stderr, " %02x", *p++);
	}
	fprintf(stderr, "\n");
}

int
main(int argc, char **argv)
{
	struct license		 input;
	const char		*name = NULL;
	const char		*email = NULL;
	const char		*keyfile = NULL;
	SHA_CTX			 ctx;
	BIO			*bio;
	EVP_PKEY		*pubkey, *privkey;
	EC_KEY			*eckey;
	ECDSA_SIG		*sig;
	unsigned char		*bin = NULL;
	const unsigned char	*bin_copy;
	unsigned char		*encrypted_name;
	char			*license, *e;
	size_t			 sz;
	int			 c, i;

	bzero(&input, sizeof(input));

	while ((c = getopt(argc, argv, "he:n:k:s:")) != EOF) {
		switch (c) {
		case 'h':
			usage();
			break;
		case 'e':
			email = optarg;
			break;
		case 'n':
			name = optarg;
			break;
		case 'k':
			keyfile = optarg;
			break;
		case 's':
			input.head.serial = atoi(optarg);
			break;
		default:
		case '?':
			return 1;
		}
	}

	printf("sizeof input = %lu\n", sizeof(input));
	printf("sizeof input.head = %lu\n", sizeof(input.head));

	if (email == NULL)
		errx(10, "missing license owner email");

	if (name == NULL)
		errx(2, "missing license owner name");

	if (input.head.serial == 0)
		errx(12, "missing serial number");

	if (keyfile == NULL)
		errx(3, "missing private key file");

	if (SHA1_Init(&ctx) != 1 ||
	    SHA1_Update(&ctx, name, strlen(name)) != 1 ||
	    SHA1_Update(&ctx, email, strlen(email)) != 1 ||
	    SHA1_Final(input.name_digest, &ctx) != 1)
		err(11, "SHA1");

	printf("SHA1 (length %i)\n", SHA_DIGEST_LENGTH);
	hexdump(input.name_digest, SHA_DIGEST_LENGTH);

	input.head.created_at = (time(NULL) - LICENSE_EPOCH) / 86400;

	bio = BIO_new_file(keyfile, "r");
	if (bio == NULL)
		err(4, "BIO_new_file");

	if ((eckey = PEM_read_bio_ECPrivateKey(bio, NULL, NULL, NULL)) == NULL)
		err(5, "PEM_read_bio_ECPrivateKey");

	/* check keys */
	if (!EC_KEY_check_key(eckey))
		errx(16, "public and private key don't match");

	printf("digest (length %lu)\n", sizeof(input)-3);
	hexdump(&input, sizeof(input)-3);

	/* sign */
	sig = ECDSA_do_sign((const unsigned char *)&input, sizeof(input) - 3, eckey);
	if (sig == NULL) {
		unsigned long e = ERR_get_error();
		ERR_load_crypto_strings();
		errx(17, "ECDSA_do_sign: %s", ERR_error_string(e, NULL));
	}

	size_t rlen = BN_num_bytes(sig->r);
	size_t slen = BN_num_bytes(sig->s);
	printf("rlen = %zu, slen = %zu\n", rlen, slen);
	sz = sizeof(input.head) + rlen + slen;

	if ((bin = malloc(sz)) == NULL)
		err(6, "malloc");
	bzero(bin, sz);
	printf("sz = %zu\n", sz);

	bcopy(&input.head, bin, sizeof(input.head));
	BN_bn2bin(sig->r, bin + sizeof(input.head));
	BN_bn2bin(sig->s, bin + sizeof(input.head) + rlen); /* join two values into bin */
	ECDSA_SIG_free(sig);

	printf("signature (r || s):\n");
	hexdump(bin + sizeof(input.head), sz - sizeof(input.head));

	if ((license = malloc(sz * 2)) == NULL)
		err(6, "malloc");

	int len;
	if ((len = b32_ntop(bin, sz, license, sz * 2)) == -1)
		err(8, "b32_ntop");

	printf("base32 length = %i\n", len);

	for (i = 0; license[i]; i++) {
		if (i > 0 && i % 8 == 0)
			printf("-");
		printf("%c", license[i]);
	}
	printf("\n");

	return 0;
}

