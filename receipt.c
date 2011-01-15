#include <sys/stat.h>

#include <err.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <openssl/bio.h>
#include <openssl/pkcs7.h>
#include <openssl/x509.h>

#include "receipt.h"
#include "ber.h"
#include "sha1.h"

#define ERRMSG	"receipt validation failed"

#define DEBUG

#ifdef DEBUG
# define DPRINTF(...)	do { fprintf(stderr, "%s:%d: ", __func__, __LINE__); \
			     fprintf(stderr, __VA_ARGS__); \
			     fprintf(stderr, "\n"); } while(0)
#else
# define DPRINTF(x...)	do { } while (0)
#endif

void	 hexdump(void *data, size_t len, const char *fmt, ...);
void	 ldap_debug_elements(struct ber_element *root, int context,
	    const char *fmt, ...);

static inline int
receipt_parse_payload(void *buf, size_t len, void **payload, size_t *payload_len)
{
	BIO *b_p7;		/* The PKCS #7 container (the receipt) and the output of the verification. */
	PKCS7 *p7;
	BIO *b_x509;		/* The Apple Root CA, as raw data and in its OpenSSL representation. */
	X509 *Apple;
	X509_STORE *store;	/* The root certificate for chain-of-trust verification. */
	BIO *b_out;
	int ret;

	if ((store = X509_STORE_new()) == NULL)
		return -1;
 
	/* Initialize both BIO variables using BIO_new_mem_buf()
	 * with a buffer and its size. */
	DPRINTF("init BIO with %zu bytes of memory", len);
	if ((b_p7 = BIO_new_mem_buf(buf, len)) == NULL)
		return -1;
 
	/* Initialize b_out as an output BIO to hold the receipt
	 * payload extracted during signature verification. */
	if ((b_out = BIO_new(BIO_s_mem())) == NULL)
		return -1;
 
	/* Capture the content of the receipt file and populate the
	 * p7 variable with the PKCS #7 container. */
	if ((p7 = d2i_PKCS7_bio(b_p7, NULL)) == NULL)
		return -1;
 
	/* Load the Apple Root CA into b_X509. */
 
	/* Initialize b_x509 as an input BIO with a value of the
	 * Apple Root CA then load it into X509 data structure. Then
	 * add the Apple Root CA to the structure. */
	DPRINTF("init Apple Root CA x509");
	if ((Apple = d2i_X509_bio(b_x509, NULL)) == NULL)
		return -1;
	DPRINTF("adding Apple Root CA");
	ret = X509_STORE_add_cert(store, Apple);
	printf("X509_STORE_add_cert returned %d\n", ret);
 
	/* Verify the signature. If the verification is correct,
	 * b_out will contain the PKCS #7 payload and rc will be 1. */
	if ((ret = PKCS7_verify(p7, NULL, store, NULL, b_out, 0)) != 1) {
		return -1;
	}
 
	/*
	 * For additional security, you may verify the fingerprint
	 * of the root CA and the OIDs of the intermediate CA and
	 * signing certificate. The OID in the Certificate Policies
	 * Extension of the intermediate CA is (1 2 840 113635 100 5
	 * 6 1), and the Marker OID of the signing certificate is (1
	 * 2 840 113635 100 6 11 1).
	 */

	*payload_len = BIO_get_mem_data(b_out, payload);
	return 0;
}

static inline int
receipt_read(const char *path, void **buf, size_t *len)
{
	struct stat	 stbuf;
	int		 fd;

	if ((fd = open(path, O_RDONLY)) == -1)
		return -1;

	if (fstat(fd, &stbuf) == -1) {
		close(fd);
		return -1;
	}

	if (stbuf.st_size >= SIZE_MAX)
		return -1;
	*len = stbuf.st_size;

	if ((*buf = malloc(*len)) == NULL) {
		close(fd);
		return -1;
	}

	if (read(fd, *buf, *len) != *len) {
		free(*buf);
		close(fd);
		return -1;
	}

	if (close(fd) == -1) {
		free(*buf);
		return -1;
	}

	return 0;
}

/*
 * Exits (or stops execution) if receipt fails to validate.
 */
void
receipt_validate(const char *receipt_path)
{
	struct ber_oid		 oid, content_type;
	struct ber		 ber, ber2;
	struct ber_element	*root, *attr;
	void			*buf;
	void			*content, *value, *payload;
	size_t			 sz, len;
	int			 fd, version, type;

	DPRINTF("validating receipt in %s", receipt_path);

	if (receipt_read(receipt_path, &buf, &sz) == -1)
		goto fail;

	DPRINTF("parsing %zu bytes of receipt", sz);
	if (receipt_parse_payload(buf, sz, &payload, &len) == -1)
		goto fail;

	ber_set_readbuf(&ber, buf, sz);
	if ((root = ber_read_elements(&ber, NULL)) == NULL)
		goto fail;
	ldap_debug_elements(root, -1, "ber encoding:");

	if (ber_scanf(root, "{o{{dS{o{x}", &oid, &version, &content_type, &content, &len) == -1)
		goto fail;

	DPRINTF("got PKCS#7 version %d", version);

	// oid should be 1.2.840.113549.1.7.2
	// content_type should be 1.2.840.113549.1.7.1

	DPRINTF("parsing %zu bytes of ContentInfo", len);
	ber_set_readbuf(&ber2, content, len);
	if ((root = ber_read_elements(&ber2, NULL)) == NULL)
		goto fail;
	ldap_debug_elements(root, -1, "PKCS#7 signed content:");

	if (ber_scanf(root, "(e", &attr) == -1)
		goto fail;

	for (; attr; attr = attr->be_next) {
		if (ber_scanf(attr, "{ddx", &type, &version, &value, &len) == -1)
			goto fail;
		printf("got attribute type %d, version %d, value len %zu\n",
		    type, version, len);

		if (type == 2) {
			ber_set_readbuf(&ber, value, len);
			if ((root = ber_read_elements(&ber, NULL)) == NULL)
				goto fail;
			if (ber_scanf(root, "U", &value) == -1)
				goto fail;
			printf("bundle identifier is %s\n", (char *)value);
		} else if (type == 3) {
			ber_set_readbuf(&ber, value, len);
			if ((root = ber_read_elements(&ber, NULL)) == NULL)
				goto fail;
			if (ber_scanf(root, "U", &value) == -1)
				goto fail;
			printf("application version is %s\n", (char *)value);
		} else if (type == 4)
			hexdump(value, len, "opaque value");
		else if (type == 5)
			hexdump(value, len, "SHA-1 digest");
	}

	return;

fail:
	err(173, ERRMSG);
}

void
receipt_validate_bundle(const char *bundle_path)
{
	char	*receipt_path;

	if (asprintf(&receipt_path, "%s/Contents/_MASReceipt/receipt", bundle_path) == -1)
		err(173, ERRMSG);
	receipt_validate(receipt_path);
	free(receipt_path);
}

#ifdef TEST

int
main(int argc, char **argv)
{
	if (argc < 2)
		errx(1, "missing receipt filename");
	receipt_validate(argv[1]);
	printf("receipt %s ok\n", argv[1]);
	return 0;
}

#endif

