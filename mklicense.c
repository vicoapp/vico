#include <err.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <resolv.h>

#include "license.h"

void
usage(void)
{
	extern const char	*__progname;

	printf("syntax: %s [-h] [-n name] [-e email] [-k keyfile] [-s serial]\n", __progname);
	exit(0);
}

int
main(int argc, char **argv)
{
	struct license	 input;
	const char	*name = NULL;
	const char	*email = NULL;
	const char	*keyfile = NULL;
	SHA_CTX		 ctx;
	BIO		*bio;
	RSA		*rsa = NULL;
	unsigned char	*encrypted_license;
	char		*license, *e;
	size_t		 sz;
	int		 c, i;

	bzero(&input, sizeof(input));
	ERR_load_crypto_strings();

	while ((c = getopt(argc, argv, "hae:n:k:s:")) != EOF) {
		switch (c) {
		case 'h':
			usage();
			break;
		case 'a':
			input.flags |= LICENSE_F_ACADEMIC;
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

	if (email == NULL)
		errx(10, "missing license owner email");

	if (name == NULL)
		errx(2, "missing license owner name");

	if (input.serial == 0)
		errx(12, "missing serial number");

	if (keyfile == NULL)
		errx(3, "missing private key file");

	if (SHA1_Init(&ctx) != 1 ||
	    SHA1_Update(&ctx, name, strlen(name)) != 1 ||
	    SHA1_Update(&ctx, email, strlen(email)) != 1 ||
	    SHA1_Final(input.name_digest, &ctx) != 1)
		err(11, "SHA1");

	input.created_at = time(NULL) - LICENSE_EPOCH;

	if ((bio = BIO_new_file(keyfile, "r")) == NULL)
		errx(4, "BIO_new_file: %s", ERR_error_string(ERR_get_error(), NULL));

	if ((rsa = PEM_read_bio_RSAPrivateKey(bio, NULL, NULL, NULL)) == 0)
		errx(5, "PEM_read_bio_RSAPrivateKey: %s", ERR_error_string(ERR_get_error(), NULL));

	sz = RSA_size(rsa);
	if ((encrypted_license = malloc(sz)) == NULL)
		err(6, "malloc");

	if (RSA_private_encrypt(sizeof(input), (uint8_t *)&input, encrypted_license,
	    rsa, RSA_PKCS1_PADDING) == -1)
		errx(7, "RSA_private_encrypt: %s", ERR_error_string(ERR_get_error(), NULL));

	if ((license = malloc(sz * 2)) == NULL)
		err(6, "malloc");

	int len;
	if ((len = b64_ntop(encrypted_license, sz, license, sz * 2)) == -1)
		err(8, "b64_ntop");

	printf("-----BEGIN LICENSE-----\n");
	for (i = 0; i < len; i++) {
		if (i > 0 && i % 43 == 0)
			printf("\n");
		printf("%c", license[i]);
	}
	printf("\n-----END LICENSE-----\n");

	free(license);

	return 0;
}

