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
	unsigned char		*encrypted_name;
	char			*license;
	int			 c;

	bzero(&input, sizeof(input));
	OpenSSL_add_all_algorithms();
	ERR_load_crypto_strings();

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
		default:
		case '?':
			return 1;
		}
	}

	argc -= optind;
	argv += optind;

	if (argc == 0)
		errx(1, "missing license key");

	license = argv[0];

	printf("sizeof input = %lu\n", sizeof(input));
	printf("sizeof input.head = %lu\n", sizeof(input.head));

	if (email == NULL)
		errx(10, "missing license owner email");

	if (name == NULL)
		errx(2, "missing license owner name");

	if (keyfile == NULL)
		errx(3, "missing private key file");

	bio = BIO_new_file(keyfile, "r");
	if (bio == NULL)
		err(3, "BIO_new_mem_buf");

	if ((eckey = PEM_read_bio_EC_PUBKEY(bio, NULL, NULL, NULL)) == NULL)
		err(3, "PEM_read_bio_EC_PUBKEY: %s", ERR_error_string(ERR_get_error(), NULL));

	/* check keys */
	if (!EC_KEY_check_key(eckey))
		errx(16, "bad key");

	BIO_free(bio);

	if (SHA1_Init(&ctx) != 1 ||
	    SHA1_Update(&ctx, name, strlen(name)) != 1 ||
	    SHA1_Update(&ctx, email, strlen(email)) != 1 ||
	    SHA1_Final(input.name_digest, &ctx) != 1)
		err(11, "SHA1");

	printf("SHA1 (length %i)\n", SHA_DIGEST_LENGTH);
	hexdump(input.name_digest, SHA_DIGEST_LENGTH);

	const char *e;
	char *ec, tmp[256];
	uint8_t license_data[256];
	for (e = license, ec = tmp; *e; e++)
		if (*e != ' ' && *e != '-')
			*ec++ = *e;
	*ec = '\0';
	printf("tmp = %s\n", tmp);
	int license_len = b32_pton(tmp, license_data, sizeof(license_data));
	printf("license_len = %i\n", license_len);

	bcopy(license_data, &input.head, sizeof(struct license_head));

	printf("serial = %u\n", input.head.serial);
	printf("flags = %0X\n", input.head.flags);
	printf("created_at = %u\n", input.head.created_at);

	if ((sig = ECDSA_SIG_new()) == NULL)
		err(1, "ECDSA_SIG_new");
	const unsigned char *p = license_data;
	p += sizeof(struct license_head);

	printf("signature (r || s):\n");
	hexdump(p, 2*LICENSE_BIGNUM_LENGTH);

	if (BN_bin2bn(p, LICENSE_BIGNUM_LENGTH, sig->r) == NULL)
		err(1, "BN_bin2bn(r)");
	p += LICENSE_BIGNUM_LENGTH;
	if (BN_bin2bn(p, LICENSE_BIGNUM_LENGTH, sig->s) == NULL)
		err(1, "BN_bin2bn(s)");

	printf("digest (length %lu)\n", sizeof(input)-3);
	hexdump(&input, sizeof(input)-3);

	int rc = ECDSA_do_verify((const unsigned char *)&input, sizeof(input) - 3, sig, eckey);
	printf("rc = %i\n", rc);
	if (rc == -1)
		err(3, "ECDSA_do_verify: %s", ERR_error_string(ERR_get_error(), NULL));

	return 0;
}

