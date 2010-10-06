#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <resolv.h>
#include <ctype.h>

#include "license_pubkey.c"
#include "license.h"

#define PUBKEY_LEN 271

#define ASSERT_ARGUMENTS()				\
	if (owner_name == NULL || *owner_name == 0)	\
		goto error;				\
	if (license_key == NULL || *license_key == 0)	\
		goto error;

/* Create SHA-1 digest of owner name.
 */
#define CREATE_OWNER_DIGEST()						\
	uint8_t owner_digest[SHA_DIGEST_LENGTH];			\
	SHA_CTX ctx;							\
	if (SHA1_Init(&ctx) != 1 ||					\
	    SHA1_Update(&ctx, owner_name, strlen(owner_name)) != 1 ||	\
	    SHA1_Update(&ctx, owner_email, strlen(owner_email)) != 1 ||	\
	    SHA1_Final(owner_digest, &ctx) != 1)			\
		goto error;

/* base64-decode the license key.
 */
#define BASE64_DECODE_LICENSE_KEY()					\
	const char *e = license_key;					\
	char *ec, tmp[256];						\
	uint8_t license_data[256];					\
	if (strncmp(e, "-----BEGIN LICENSE-----", 23) == 0)		\
		e += 24;						\
	for (ec = tmp; *e && *e != '-'; e++)				\
		if (isalnum(*e) || *e == '+' || *e == '/' || *e == '=')	\
			*ec++ = *e;					\
	*ec = '\0';							\
	int license_len = b64_pton(tmp, license_data,			\
		sizeof(license_data));					\
	if (license_len != 128)						\
		goto error;

/* Retrieve the real public key by xor-ing with fake public key.
 */
#define RETRIEVE_PUBLIC_KEY()				\
	uint8_t pubkey[PUBKEY_LEN];			\
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
	RSA *rsa_key;					\
	rsa_key = PEM_read_bio_RSA_PUBKEY(bio, NULL,	\
	    NULL, NULL);				\
	bzero(pubkey, sizeof(pubkey));			\
	BIO_free(bio);					\
	if (rsa_key == NULL)				\
		goto error;

#define DECRYPT_LICENSE()				\
	uint8_t decrypted_license[128];			\
	int n = RSA_public_decrypt(license_len,		\
	    license_data, decrypted_license, rsa_key,	\
	    RSA_PKCS1_PADDING);				\
	RSA_free(rsa_key);				\
	if (n != sizeof(struct license))		\
		goto error;

#define FINALIZE()							\
	struct license *input = (struct license *)decrypted_license;	\
	if (created_at)							\
		*created_at = input->created_at + LICENSE_EPOCH;	\
	if (serial)							\
		*serial = input->serial;				\
	if (flags)							\
		*flags = input->flags;					\
	int rc = bcmp(owner_digest, input->name_digest,			\
	    SHA_DIGEST_LENGTH);						\
	bzero(decrypted_license, sizeof(decrypted_license));		\
	return rc;							\
error:									\
	bzero(pubkey, sizeof(pubkey));					\
	return -1;

/* Returns 0 if the license key corresponds to the owner name.
 * Decrypts the license_key using the public key and matches against owner.
 * The license_key is base64-encoded.
 *
 * FIXME: memory leak of the RSA key?
 */
__inline__ int
check_license_1(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	ASSERT_ARGUMENTS();
	CREATE_OWNER_DIGEST();
	BASE64_DECODE_LICENSE_KEY();
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	DECRYPT_LICENSE();
	FINALIZE();
}

__inline__ int
check_license_2(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	ASSERT_ARGUMENTS();
	RETRIEVE_PUBLIC_KEY();
	BASE64_DECODE_LICENSE_KEY();
	LOAD_PUBLIC_KEY();
	DECRYPT_LICENSE();
	CREATE_OWNER_DIGEST();
	FINALIZE();
}

__inline__ int
check_license_3(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	ASSERT_ARGUMENTS();
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	CREATE_OWNER_DIGEST();
	BASE64_DECODE_LICENSE_KEY();
	DECRYPT_LICENSE();
	FINALIZE();
}

__inline__ int
check_license_4(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags)
{
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	ASSERT_ARGUMENTS();
	BASE64_DECODE_LICENSE_KEY();
	CREATE_OWNER_DIGEST();
	DECRYPT_LICENSE();
	FINALIZE();
}

__inline__ int
check_license_quick(const char *license_key)
{
	BASE64_DECODE_LICENSE_KEY();
	return 0;
error:
	return -1;
}

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
	const char *license_key = "5R9UO-TFCBH-1VCE3-UK1S8-4K1VR-MILMV-JA2N6-75IR8-6KGJ5-LV0PS-TPCBK-3B65T-VPFO9-130IG-EJ40I-F7OA9-B5F5H-CFE3K-5F6UP-JCJCF-LFSH0-V0UPU-E5NUN-QN177-U9QMM-KSKQ1-4768H-NIRCD-Q6QNI-SEB3Q-DLELR-4QD3J-1KC8H-L3TAG-B7BD8-DCBT8-42EN5-7MMOM-A8B0L-F3PI6-JO1MM";
	const char *owner_name = "Martin Hedenfalk";

	fail_unless(check_license_1(owner_name, license_key) == 0);
	fail_unless(check_license_2(owner_name, license_key) == 0);
	fail_unless(check_license_3(owner_name, license_key) == 0);
	fail_unless(check_license_4(owner_name, license_key) == 0);

	fail_unless(check_license_1("Fake Owner Name", license_key) != 0);
	fail_unless(check_license_2("Fake Owner Name", license_key) != 0);
	fail_unless(check_license_3("Fake Owner Name", license_key) != 0);
	fail_unless(check_license_4("Fake Owner Name", license_key) != 0);

	/* Check handling of illegal base64 data
	 */
	const char *illegal_license_key =
	  "asdfasdfASFASDFASDF_________";
	fail_unless(check_license_1("Illegal key", illegal_license_key) != 0);

	/* Check some corner cases.
	 */
	fail_unless(check_license_1("", license_key) != 0);
	fail_unless(check_license_2(NULL, license_key) != 0);
	fail_unless(check_license_3(owner_name, "") != 0);
	fail_unless(check_license_4(owner_name, NULL) != 0);

	return 0;
}

#endif

