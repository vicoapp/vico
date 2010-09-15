#ifndef _license_h_
#define _license_h_

#include <openssl/sha.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/bio.h>

#define LICENSE_EPOCH		1262304000 /* Fri Jan  1 00:00:00 UTC 2010 */

#define LICENSE_F_ACADEMIC	1

struct license {
	unsigned	 flags : 20;
	unsigned	 serial : 20;
	uint32_t	 created_at;
	uint8_t		 name_digest[SHA_DIGEST_LENGTH];
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
check_license_quick(const char *license_key);

#endif


