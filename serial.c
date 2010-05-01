#include <netinet/in.h>

#include <openssl/sha.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/bio.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "key.c"
#include "xor.c"
#include "b32.h"
#include "serial.h"

#define PUBKEY_LEN 271

#define ASSERT_ARGUMENTS()				\
	if (owner_name == NULL || *owner_name == 0)	\
		goto error;				\
	if (license_key == NULL || *license_key == 0)	\
		goto error;

/* Create SHA-1 digest of owner name.
 */
#define CREATE_OWNER_DIGEST()				\
	uint8_t owner_digest[SHA_DIGEST_LENGTH];	\
	SHA1((const unsigned char *)owner_name,		\
	    strlen(owner_name), owner_digest);

/* base32-decode the license key.
 */
#define BASE32_DECODE_LICENSE_KEY()			\
	const char *e;					\
	char *ec, tmp[256];				\
	unsigned char license_data[256];		\
	for (e = license_key, ec = tmp; *e; e++)	\
		if (*e != ' ' && *e != '-')		\
			*ec++ = *e;			\
	*ec = '\0';					\
	int license_len = b32_pton(tmp, license_data,	\
		sizeof(license_data));			\
	printf("license_len = %i\n", license_len); \
	if (license_len != 129)				\
		goto error;

/* Retrieve the real public key by xor-ing with fake public key.
 */
#define RETRIEVE_PUBLIC_KEY()				\
	char pubkey[PUBKEY_LEN];			\
	int ipk;					\
	for (ipk = 0; ipk < PUBKEY_LEN; ipk++)		\
	    pubkey[ipk] =				\
	        real_pubkey[ipk] ^ fake_pubkey[ipk];

/* Create a BIO and load the public key.
 */
#define LOAD_PUBLIC_KEY()				\
	BIO *bio = BIO_new_mem_buf(pubkey, PUBKEY_LEN);	\
	if (bio == NULL)				\
		goto error;				\
	RSA *rsa_key = 0;				\
	if (PEM_read_bio_RSA_PUBKEY(bio, &rsa_key,	\
	    NULL, NULL) == 0) {				\
		BIO_free(bio);				\
		goto error;				\
	}						\
	bzero(pubkey, sizeof(pubkey));

#define DECRYPT_LICENSE()				\
	unsigned char decrypted_digest[128];		\
	int n = RSA_public_decrypt(license_len,		\
	    license_data, decrypted_digest, rsa_key,	\
	    RSA_PKCS1_PADDING);				\
	RSA_free(rsa_key);				\
	BIO_free(bio);					\
	if (n != SHA_DIGEST_LENGTH)			\
		goto error;

#define FINALIZE()					\
	return bcmp(owner_digest, decrypted_digest,	\
	    SHA_DIGEST_LENGTH);				\
error:							\
	bzero(pubkey, sizeof(pubkey));			\
	return -1;
	

/* Returns 0 if the license key corresponds to the owner name.
 * Decrypts the license_key using the public key and matches against owner.
 * The license_key is base64-encoded.
 *
 * FIXME: memory leak of the RSA key?
 */
__inline__ int
check_license_1(const char *owner_name, const char *license_key)
{
	ASSERT_ARGUMENTS();
	CREATE_OWNER_DIGEST();
	BASE32_DECODE_LICENSE_KEY();
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	DECRYPT_LICENSE();
	FINALIZE();
}

__inline__ int
check_license_2(const char *owner_name, const char *license_key)
{
	ASSERT_ARGUMENTS();
	RETRIEVE_PUBLIC_KEY();
	BASE32_DECODE_LICENSE_KEY();
	LOAD_PUBLIC_KEY();
	DECRYPT_LICENSE();
	CREATE_OWNER_DIGEST();
	FINALIZE();
}

__inline__ int
check_license_3(const char *owner_name, const char *license_key)
{
	ASSERT_ARGUMENTS();
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	CREATE_OWNER_DIGEST();
	BASE32_DECODE_LICENSE_KEY();
	DECRYPT_LICENSE();
	FINALIZE();
}

__inline__ int
check_license_4(const char *owner_name, const char *license_key)
{
	RETRIEVE_PUBLIC_KEY();
	LOAD_PUBLIC_KEY();
	ASSERT_ARGUMENTS();
	BASE32_DECODE_LICENSE_KEY();
	CREATE_OWNER_DIGEST();
	DECRYPT_LICENSE();
	FINALIZE();
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

