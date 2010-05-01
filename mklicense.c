#include <err.h>
#include <openssl/bio.h>
#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/sha.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include "b32.h"

void
usage(void)
{
	extern const char	*__progname;

	printf("syntax: %s [-h] [-n name] [-k keyfile]\n", __progname);
	exit(0);
}

int
main(int argc, char **argv)
{
	struct {
		unsigned	 serial : 24;
		unsigned	 flags : 8;
		uint16_t	 created_at;
		uint8_t		 name_digest[SHA_DIGEST_LENGTH];
	} __attribute__((packed)) input;
	const char		*name = NULL;
	const char		*email = NULL;
	const char		*keyfile = NULL;
	SHA_CTX			 ctx;
	BIO			*bio;
	RSA			*rsa = NULL;
	EVP_PKEY		*pubkey, *privkey;
	EC_KEY			*eckey;
	ECDSA_SIG		*sig;
	unsigned char		*bin = NULL;
	const unsigned char	*bin_copy;
	unsigned char		*encrypted_name;
	char			*license, *e;
	size_t			 sz;
	int			 c, i;

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
			input.serial = atoi(optarg);
			break;
		default:
		case '?':
			return 1;
		}
	}

	printf("sizeof input = %lu\n", sizeof(input));

	if (email == NULL)
		errx(10, "missing license owner email");

	if (name == NULL)
		errx(2, "missing license owner name");

	if (input.serial == 0)
		errx(12, "missing serial number");

	if (keyfile == NULL)
		errx(3, "missing private key file");

	bzero(&input, sizeof(input));

	if (SHA1_Init(&ctx) != 1 ||
	    SHA1_Update(&ctx, name, strlen(name)) != 1 ||
	    SHA1_Update(&ctx, email, strlen(email)) != 1 ||
	    SHA1_Final(input.name_digest, &ctx) != 1)
		err(11, "SHA1");

	input.created_at = time(NULL) / 86400;

	eckey = EC_KEY_new_by_curve_name(NID_secp112r1);
	if (eckey == NULL)
		err(13, "EC_KEY_new_by_curve_name");

	bio = BIO_new_file(keyfile, "r");
	if (bio == NULL)
		err(4, "BIO_new_file");

	if (PEM_read_bio_ECPrivateKey(bio, &eckey, NULL, NULL) == NULL)
		err(5, "PEM_read_bio_ECPrivateKey");

	/* check keys */
	if (!EC_KEY_check_key(eckey))
		errx(16, "public and private key don't match");

	/* sign */
	sig = ECDSA_do_sign((const unsigned char *)&input, sizeof(input) - sizeof(uint16_t), eckey);
	if (sig == NULL) {
		unsigned long e = ERR_get_error();
		ERR_load_crypto_strings();
		errx(17, "ECDSA_do_sign: %s", ERR_error_string(e, NULL));
	}

	size_t rlen = BN_num_bytes(sig->r);
	size_t slen = BN_num_bytes(sig->s);
	sz = rlen + slen;

	if ((bin = malloc(sz)) == NULL)
		err(6, "malloc");
	bzero(bin, sz);

	BN_bn2bin(sig->r, bin);
	BN_bn2bin(sig->s, bin + rlen); /* join two values into bin */
	ECDSA_SIG_free(sig);

	if ((license = malloc(sz * 2)) == NULL)
		err(6, "malloc");

	if (b32_ntop(bin, sz, license, sz * 2) == -1)
		err(8, "b32_ntop");

	for (i = 0; license[i]; i++) {
		if (i > 0 && i % 7 == 0)
			printf("-");
		printf("%c", license[i]);
	}
	printf("\n");

	return 0;
}

