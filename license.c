#include <netinet/in.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>

#import "license_pubkey.c"
#include "b32.h"
#include "license.h"

#define PUBKEY_LEN 149

#define DECLARE_VARIABLES()		\
	struct license input;		\
	bzero(&input, sizeof(input));	\
	ECDSA_SIG *ec_sig = NULL;	\
	ERR_load_crypto_strings();

#define ASSERT_ARGUMENTS()					\
	if (owner_name == NULL || *owner_name == '\0')		\
		goto error;					\
	if (owner_email == NULL || *owner_email == '\0')	\
		goto error;					\
	if (license_key == NULL || *license_key == '\0')	\
		goto error;

/* Create SHA-1 digest of owner name.
 */
#define CREATE_OWNER_DIGEST()						\
	SHA_CTX ctx;							\
	if (SHA1_Init(&ctx) != 1 ||					\
	    SHA1_Update(&ctx, owner_name, strlen(owner_name)) != 1 ||	\
	    SHA1_Update(&ctx, owner_email, strlen(owner_email)) != 1 ||	\
	    SHA1_Final(input.name_digest, &ctx) != 1)			\
		goto error;

/* base32-decode the license key.
 */
#define BASE32_DECODE_LICENSE_KEY()			\
	const char *e;					\
	char *ec, tmp[256];				\
	uint8_t license_data[256];			\
	for (e = license_key, ec = tmp; *e; e++)	\
		if (*e != ' ' && *e != '-')		\
			*ec++ = *e;			\
	*ec = '\0';					\
	int license_len = b32_pton(tmp, license_data,	\
		sizeof(license_data));			\
	bzero(&tmp, sizeof(tmp));			\
	if (license_len != 55)				\
		goto error;

/* Copy timestamp, flags and serial from head of license key.
 */
#define ASSEMBLE_LICENSE_HEAD()						\
	bcopy(license_data, &input.head, sizeof(struct license_head));	\
	if (created_at)							\
		*created_at = input.head.created_at * 86400 + LICENSE_EPOCH;	\
	if (serial)							\
		*serial = input.head.serial;				\
	if (flags)							\
		*flags = input.head.flags;

/* Retrieve the real public key by xor-ing with fake public key.
 */
#define RETRIEVE_PUBLIC_KEY()				\
	char pubkey[PUBKEY_LEN];			\
	int ipk;					\
	for (ipk = 0; ipk < PUBKEY_LEN; ipk++)		\
	    pubkey[ipk] =				\
	        (real_pubkey[ipk] ^ xor_key[ipk]) ^ fake_pubkey[ipk];

/* Create a BIO and load the public key.
 */
#define LOAD_PUBLIC_KEY()				\
	BIO *bio = BIO_new_mem_buf(pubkey, PUBKEY_LEN);	\
	if (bio == NULL)				\
		goto error;				\
	EC_KEY *ec_key = PEM_read_bio_EC_PUBKEY(bio, NULL, NULL, NULL); \
	BIO_free(bio);					\
	if (ec_key == NULL) {				\
		fprintf(stderr, "PEM_read_bio_EC_PUBKEY: %s\n", ERR_error_string(ERR_get_error(), NULL)); \
		goto error;				\
	}						\
	bzero(pubkey, sizeof(pubkey));

#define READ_SIGNATURE()				\
	ec_sig = ECDSA_SIG_new();			\
	if (ec_sig == NULL)				\
		goto error;				\
	const unsigned char *p = license_data;		\
	p += sizeof(struct license_head);		\
	if (BN_bin2bn(p, LICENSE_BIGNUM_LENGTH, ec_sig->r) == NULL)	\
		goto error;				\
	p += LICENSE_BIGNUM_LENGTH;			\
	if (BN_bin2bn(p, LICENSE_BIGNUM_LENGTH, ec_sig->s ) == NULL)	\
		goto error;

#define CLEANUP()					\
	if (ec_sig != NULL) {				\
		BN_clear(ec_sig->r);			\
		BN_clear(ec_sig->s);			\
		ECDSA_SIG_free(ec_sig);			\
	}						\
	bzero(&pubkey, sizeof(pubkey));			\
	bzero(&input, sizeof(input));

#define FINALIZE()					\
	int rc = ECDSA_do_verify((const unsigned char *)&input, sizeof(input) - 3,	\
	    ec_sig, ec_key);				\
	if (0 && rc == -1) {				\
		unsigned long c = ERR_get_error();	\
		fprintf(stderr, "ECDSA_do_verify: %s\n",\
		    ERR_error_string(c, NULL));		\
	}						\
	CLEANUP();					\
	return rc == 1 ? 1 : 0;				\
error:							\
	CLEANUP();					\
	return 0;


/* Returns 0 if the license key corresponds to the owner name.
 * Decrypts the license_key using the public key and matches against owner.
 * The license_key is base32-encoded.
 */
__inline__ int
check_license_1(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	DECLARE_VARIABLES();
	ASSERT_ARGUMENTS();
	CREATE_OWNER_DIGEST();
	BASE32_DECODE_LICENSE_KEY();
	ASSEMBLE_LICENSE_HEAD();
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	READ_SIGNATURE();
	FINALIZE();
}

__inline__ int
check_license_2(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	DECLARE_VARIABLES();
	ASSERT_ARGUMENTS();
	RETRIEVE_PUBLIC_KEY();
	BASE32_DECODE_LICENSE_KEY();
	READ_SIGNATURE();
	ASSEMBLE_LICENSE_HEAD();
	LOAD_PUBLIC_KEY();
	CREATE_OWNER_DIGEST();
	FINALIZE();
}

__inline__ int
check_license_3(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	DECLARE_VARIABLES();
	ASSERT_ARGUMENTS();
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	CREATE_OWNER_DIGEST();
	BASE32_DECODE_LICENSE_KEY();
	ASSEMBLE_LICENSE_HEAD();
	READ_SIGNATURE();
	FINALIZE();
}

__inline__ int
check_license_4(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	DECLARE_VARIABLES();
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	ASSERT_ARGUMENTS();
	BASE32_DECODE_LICENSE_KEY();
	READ_SIGNATURE();
	ASSEMBLE_LICENSE_HEAD();
	CREATE_OWNER_DIGEST();
	FINALIZE();
}

__inline__ int
check_license_base32(const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	DECLARE_VARIABLES();
	BASE32_DECODE_LICENSE_KEY();
	ASSEMBLE_LICENSE_HEAD();
	return 1;
error:
	return 0;
}

#ifdef TOOL
int
main(int argc, char **argv)
{
	if (argc < 3)
		errx(1, "missing license owner and email");

	const char *owner = argv[1];
	const char *email = argv[2];
}
#endif

#ifdef TEST

#define fail_unless(test) \
    do { if (!(test)) { \
        fprintf(stderr, \
                "----------------------------------------------\n" \
                "%s:%d: test FAILED:\nFailed test: %s\n" \
                "----------------------------------------------\n", \
                __FILE__, __LINE__, #test); \
        exit(1); \
    } } while (0)

int
main(int argc, char **argv)
{
	const char *license_key = "00010000-000RJIE5-TT8SOF7U-EPJGNRG0-88MT0H2F-HA2H3VDP-8U691MOF-P4DESUM3-GQIKUF2P-9M5B7G4P-IA4FTURG";
	const char *owner_name = "Martin Hedenfalk";
	const char *owner_email = "martin@hedenfalk.se";

	fail_unless(check_license_1(owner_name, owner_email, license_key) == 0);
	fail_unless(check_license_2(owner_name, owner_email, license_key) == 0);
	fail_unless(check_license_3(owner_name, owner_email, license_key) == 0);
	fail_unless(check_license_4(owner_name, owner_email, license_key) == 0);

	fail_unless(check_license_1("Fake Owner Name", owner_email, license_key) != 0);
	fail_unless(check_license_2("Fake Owner Name", owner_email, license_key) != 0);
	fail_unless(check_license_3("Fake Owner Name", owner_email, license_key) != 0);
	fail_unless(check_license_4("Fake Owner Name", owner_email, license_key) != 0);

	/* Check handling of illegal base32 data
	 */
	const char *illegal_license_key =
	  "asdfasdfASFASDFASDF_________";
	fail_unless(check_license_1("Illegal key", illegal_license_key) != 0);

	/* Check some corner cases.
	 */
	fail_unless(check_license_1("", "", license_key) != 0);
	fail_unless(check_license_2(NULL, NULL, license_key) != 0);
	fail_unless(check_license_3(owner_name, owner_email, "") != 0);
	fail_unless(check_license_4(owner_name, owner_email, NULL) != 0);

	return 0;
}

#endif

