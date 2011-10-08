#include <sys/types.h>

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int
main(int argc, char **argv)
{
	u_int8_t		 buf[4096];
	u_int8_t		 key[4096];
	extern const char	*__progname;
	FILE			*fp;
	int			 i;

	if (argc != 2)
		errx(1, "syntax: %s file", __progname);

	fp = fopen(argv[1], "r");
	if (fp == NULL)
		err(1, "%s", argv[1]);

	size_t r = fread(buf, 1, 4096, fp);
	if (!feof(fp))
		errx(2, "%s: file too large", argv[1]);
	fclose(fp);

	printf("size_t		 root_ca_len = %zu;\n", r);

	for (i = 0; i < r / sizeof(u_int32_t) + 1; i++)
		*(u_int32_t *)(key + i*4) = arc4random();

	printf("u_int8_t	 root_ca_xor[] = {\n");
	for (i = 0; i < r; i++) {
		if (i % 16 == 0 && i > 0)
			printf("\n");
		printf("0x%02x,", (u_int8_t)(buf[i] ^ key[i]));
	}
	printf("};\n");

	printf("u_int8_t	 root_ca_key[] = {\n");
	for (i = 0; i < r; i++) {
		if (i % 16 == 0 && i > 0)
			printf("\n");
		printf("0x%02x,", (u_int8_t)key[i]);
	}
	printf("};\n");

	return 0;
}

