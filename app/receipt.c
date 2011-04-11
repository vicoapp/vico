#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>

#include <net/if_dl.h>
#include <ifaddrs.h>

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
#include <openssl/err.h>

#include "receipt.h"
#include "ber.h"
#include "sha1.h"

#ifdef DEBUG
# define DPRINTF(...)	do { fprintf(stderr, "%s:%d: ", __func__, __LINE__); \
			     fprintf(stderr, __VA_ARGS__); \
			     fprintf(stderr, "\n"); } while(0)
# define HEXDUMP	hexdump
#else
# define DPRINTF(x...)	do { } while (0)
# define HEXDUMP(x...)  do { } while (0)
#endif

#ifdef DEBUG
void
hexdump(void *data, size_t len, const char *fmt, ...)
{
	uint8_t *p = data;
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
	va_end(ap);

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
#endif

static inline int
get_node_addr(u_int8_t *addr)
{  
#ifdef TEST_RECEIPT
	u_int8_t test_mac[6] = {0x00, 0x17, 0xf2, 0xc4, 0xbc, 0xc0};
	bcopy(test_mac, addr, 6);
	return 0;
#else
	struct sockaddr_dl *dl;
	struct ifaddrs *ifa, *ifa0;

	if (getifaddrs(&ifa0) != 0)
		return -1;

	for (ifa = ifa0; ifa != NULL; ifa = ifa->ifa_next) {
		if (ifa->ifa_addr == NULL)
			continue;

		if (strcmp(ifa->ifa_name, "en0") != 0)
			continue;

		if (ifa->ifa_addr->sa_family == AF_LINK) {
			dl = (struct sockaddr_dl *)ifa->ifa_addr;
			DPRINTF("found link addr %s", link_ntoa(dl));
			if (dl->sdl_alen == 6) {
				bcopy(LLADDR(dl), addr, 6);
				freeifaddrs(ifa0);
				return 0;
			}
		}
	}

	freeifaddrs(ifa0);
	return -1;
#endif
}

/*
 * Exits (or stops execution) if receipt fails to validate.
 */
void
receipt_validate(const char *receipt_path)
{
#include "AppleIncRootCertificate.h"
	u_int8_t		 ca_digest[SHA1_DIGEST_LENGTH];
	SHA1_CTX		 ca_ctx;
	u_int8_t		 bundle_fingerprint[SHA1_DIGEST_LENGTH] = {
#include "bundle_fingerprint.h"
	};
	u_int8_t		 ca_fingerprint[SHA1_DIGEST_LENGTH] = {
		0x61, 0x1e, 0x5b, 0x66, 0x2c, 0x59, 0x3a, 0x08,
		0xff, 0x58, 0xd1, 0x4a, 0xe2, 0x24, 0x52, 0xd1,
		0x98, 0xdf, 0x6c, 0x60
	};
	SHA1_CTX		 bundle_ctx;
	u_int8_t		 digest[SHA1_DIGEST_LENGTH];
	u_int8_t		 mac[6];
	struct ber		 ber;
	SHA1_CTX		 guid_hash;
	struct ber_element	*root, *attr;
	FILE			*fp;
	void			*value, *payload;
	PKCS7			*p7;
	X509			*Apple;
	X509_STORE		*store;
	BIO			*b_root_ca;
	BIO			*b_out;
	size_t			 len, i;
	int			 version, type;
	int			 ret;

	ERR_load_crypto_strings();

	for (i = 0; i < root_ca_len; i++) {
		SHA1Init(&bundle_ctx);
		root_ca_xor[i] ^= root_ca_key[i];
		SHA1Init(&guid_hash);
	}

	if (get_node_addr(mac) != 0) {
		DPRINTF("failed to get mac address");
		_Exit(173);
	}

	ERR_load_PKCS7_strings();

	HEXDUMP(mac, 6, "adding %i bytes of mac address to guid hash", 6);
	SHA1Update(&guid_hash, mac, 6);

	DPRINTF("validating receipt in %s", receipt_path);

	if ((fp = fopen(receipt_path, "r")) == NULL)
		_Exit(173);

	ERR_load_X509_strings();

	if ((store = X509_STORE_new()) == NULL) {
		ERR_print_errors_fp(stderr);
		_Exit(173);
	}
 
	/* Initialize b_out as an output BIO to hold the receipt
	 * payload extracted during signature verification. */
	if ((b_out = BIO_new(BIO_s_mem())) == NULL) {
		ERR_print_errors_fp(stderr);
		_Exit(173);
	}

	OpenSSL_add_all_digests();
 
	/* Capture the content of the receipt file and populate the
	 * p7 variable with the PKCS #7 container. */
	p7 = d2i_PKCS7_fp(fp, NULL);
	fclose(fp);
	if (p7 == NULL) {
		ERR_print_errors_fp(stderr);
		_exit(173);
	}
 
	/* Load the Apple Root CA into b_x509. */
	DPRINTF("loading %zu bytes from apple root ca", root_ca_len);
	if ((b_root_ca = BIO_new_mem_buf(root_ca_xor, (int)root_ca_len)) == NULL) {
		DPRINTF("failed to load apple root ca");
		ERR_print_errors_fp(stderr);
		_exit(173);
	}

	SHA1Init(&ca_ctx);
	SHA1Update(&ca_ctx, root_ca_xor, root_ca_len);
	SHA1Final(ca_digest, &ca_ctx);
	if (bcmp(ca_digest, ca_fingerprint, SHA1_DIGEST_LENGTH) != 0)
		_exit(173);
 
	/* Initialize b_x509 as an input BIO with a value of the
	 * Apple Root CA then load it into X509 data structure. Then
	 * add the Apple Root CA to the structure. */
	DPRINTF("init Apple Root CA x509");
	Apple = d2i_X509_bio(b_root_ca, NULL);
	fclose(fp);
	if (Apple == NULL) {
		DPRINTF("failed to read apple root ca");
		ERR_print_errors_fp(stderr);
		exit(173);
	}
	DPRINTF("adding Apple Root CA");
	ret = X509_STORE_add_cert(store, Apple);
	if (ret != 1) {
		DPRINTF("X509_STORE_add_cert returned %d", ret);
		ERR_print_errors_fp(stderr);
		_Exit(173);
	}
 
	/* Verify the signature. If the verification is correct,
	 * b_out will contain the PKCS #7 payload and rc will be 1. */
	if ((ret = PKCS7_verify(p7, NULL, store, NULL, b_out, 0)) != 1) {
		DPRINTF("PKCS7_verify returned %i", ret);
		ERR_print_errors_fp(stderr);
		_exit(173);
	}
 
	/*
	 * For additional security, you may verify the fingerprint
	 * of the root CA and the OIDs of the intermediate CA and
	 * signing certificate. The OID in the Certificate Policies
	 * Extension of the intermediate CA is (1 2 840 113635 100 5
	 * 6 1), and the Marker OID of the signing certificate is (1
	 * 2 840 113635 100 6 11 1).
	 */

	len = BIO_get_mem_data(b_out, &payload);
	DPRINTF("got %zu bytes of payload", len);

	ber_set_readbuf(&ber, payload, len);
	if ((root = ber_read_elements(&ber, NULL)) == NULL)
		_exit(173);

	// oid should be 1.2.840.113549.1.7.2
	// content_type should be 1.2.840.113549.1.7.1

	int d;
	unsigned long t;
	if (ber_scanf(root, "t(e", &d, &t, &attr) == -1 ||
	    d != BER_CLASS_UNIVERSAL ||
	    t != BER_TYPE_SET) {
		DPRINTF("payload not a set");
		exit(173);
	}

	void *bundle_ver = NULL;
	size_t bundle_ver_len = 0;
	void *bundle_id = NULL;
	size_t bundle_id_len = 0;
	void *opaque_buf = NULL;
	size_t opaque_len = 0;
	void *hash_buf = NULL;

	for (; attr; attr = attr->be_next) {
		if (ber_scanf(attr, "{ddx", &type, &version, &value, &len) == -1)
			_exit(173);

		if (type == 2) {
			HEXDUMP(value, len, "raw attribute 2 value");
			ber_set_readbuf(&ber, value, len);
			if ((root = ber_read_elements(&ber, NULL)) == NULL)
				_Exit(173);
			if (ber_scanf(root, "U", &bundle_id) == -1)
				exit(173);
			DPRINTF("bundle identifier is %s", (char *)bundle_id);
			HEXDUMP(bundle_id, root->be_len,
			    "adding %zu bytes of bundle id to bundle hash", root->be_len);
			SHA1Update(&bundle_ctx, bundle_id, root->be_len);
			bundle_id = value;
			bundle_id_len = len;
		} else if (type == 3) {
			ber_set_readbuf(&ber, value, len);
			if ((root = ber_read_elements(&ber, NULL)) == NULL)
				exit(173);
			if (ber_scanf(root, "U", &value) == -1)
				_exit(173);
			DPRINTF("application version: %s", (char *)value);
			bundle_ver = value;
			bundle_ver_len = root->be_len;
		} else if (type == 4) {
			HEXDUMP(value, len, "opaque value");
			opaque_buf = value;
			opaque_len = len;
		} else if (type == 5) {
			HEXDUMP(value, len, "SHA-1 digest");
			hash_buf = value;
			if (len != SHA1_DIGEST_LENGTH) {
				DPRINTF("invalid length of sha-1 digest");
				_exit(173);
			}
		}
	}


	HEXDUMP(opaque_buf, opaque_len, "adding %zu bytes of opaque data to guid hash", opaque_len);
	SHA1Update(&guid_hash, opaque_buf, opaque_len);
	HEXDUMP(bundle_id, bundle_id_len, "adding %zu bytes of bundle id to guid hash", bundle_id_len);
	SHA1Update(&guid_hash, bundle_id, bundle_id_len);

	HEXDUMP(bundle_ver, bundle_ver_len,
	    "adding %zu bytes of bundle version to bundle hash", bundle_ver_len);
	SHA1Update(&bundle_ctx, bundle_ver, bundle_ver_len);

	SHA1Final(ca_digest, &bundle_ctx); /* XXX: re-using ca_digest buffer */
	SHA1Final(digest, &guid_hash);

	HEXDUMP(ca_digest, SHA1_DIGEST_LENGTH, "computed bundle hash");
	HEXDUMP(bundle_fingerprint, SHA1_DIGEST_LENGTH, "stored bundle hash");
	if (bcmp(ca_digest, bundle_fingerprint, SHA1_DIGEST_LENGTH) != 0) {
		DPRINTF("bundle id/version fingerprint don't match");
		_exit(173);
	}

	HEXDUMP(digest, SHA1_DIGEST_LENGTH, "computed guid hash");
	if (bcmp(digest, hash_buf, SHA1_DIGEST_LENGTH) != 0) {
		DPRINTF("guid hash doesn't match");
		_Exit(173);
	}
}

void
receipt_validate_bundle(const char *bundle_path)
{
	char	*receipt_path;

	if (asprintf(&receipt_path, "%s/Contents/_MASReceipt/receipt", bundle_path) == -1)
		exit(173);
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

