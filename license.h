#ifndef _license_h_
#define _license_h_

#include <openssl/bio.h>
#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/sha.h>

#define LICENSE_EPOCH		1262304000 /* Fri Jan  1 00:00:00 UTC 2010 */
#define LICENSE_BIGNUM_LENGTH	24

struct license_head {
	unsigned	 flags : 20;
	unsigned	 serial : 20;
	unsigned	 created_at : 16;
} __attribute__((packed));

struct license {
	struct license_head	 head;
	uint8_t			 name_digest[SHA_DIGEST_LENGTH];
} __attribute__((packed));

int
check_license_1(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags);
int
check_license_2(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags);
int
check_license_3(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags);
int
check_license_4(const char *owner_name, const char *owner_email, const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags);

int
check_license_base32(const char *license_key,
    time_t *created_at, unsigned int *serial, unsigned int *flags);

#endif


