/*
 * util.c -- set of various support routines.
 *
 * Copyright (c) 2001-2006, NLnet Labs. All rights reserved.
 *
 * This software is open source.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * Neither the name of the NLNET LABS nor the names of its contributors may
 * be used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include <ctype.h>
#include <string.h>
#include <stdint.h>

int
b32_ntop(uint8_t const *src, size_t srclength, char *target, size_t targsize)
{
	static char b32[]="0123456789ABCDEFGHIJKLMNOPQRSTUV";
	char buf[9];
	ssize_t len=0;

	while(srclength > 0)
	{
		int t;
		memset(buf,'\0',sizeof buf);

		/* xxxxx000 00000000 00000000 00000000 00000000 */
		buf[0]=b32[src[0] >> 3];

		/* 00000xxx xx000000 00000000 00000000 00000000 */
		t=(src[0]&7) << 2;
		if(srclength > 1)
			t+=src[1] >> 6;
		buf[1]=b32[t];
		if(srclength == 1)
			break;

		/* 00000000 00xxxxx0 00000000 00000000 00000000 */
		buf[2]=b32[(src[1] >> 1)&0x1f];

		/* 00000000 0000000x xxxx0000 00000000 00000000 */
		t=(src[1]&1) << 4;
		if(srclength > 2)
			t+=src[2] >> 4;
		buf[3]=b32[t];
		if(srclength == 2)
			break;

		/* 00000000 00000000 0000xxxx x0000000 00000000 */
		t=(src[2]&0xf) << 1;
		if(srclength > 3)
			t+=src[3] >> 7;
		buf[4]=b32[t];
		if(srclength == 3)
			break;

		/* 00000000 00000000 00000000 0xxxxx00 00000000 */
		buf[5]=b32[(src[3] >> 2)&0x1f];

		/* 00000000 00000000 00000000 000000xx xxx00000 */
		t=(src[3]&3) << 3;
		if(srclength > 4)
			t+=src[4] >> 5;
		buf[6]=b32[t];
		if(srclength == 4)
			break;

		/* 00000000 00000000 00000000 00000000 000xxxxx */
		buf[7]=b32[src[4]&0x1f];

		if(targsize < 8)
			return -1;

		src += 5;
		srclength -= 5;

		memcpy(target,buf,8);
		target += 8;
		targsize -= 8;
		len += 8;
	}
	if(srclength)
	{
		if(targsize < strlen(buf)+1)
			return -1;
		strlcpy(target, buf, targsize);
		len += strlen(buf);
	}
	else if(targsize < 1)
		return -1;
	else
		*target='\0';
	return len;
}

int
b32_pton(const char *src, uint8_t *target, size_t tsize)
{
	char ch;
	size_t p=0;

	memset(target,'\0',tsize);
	while((ch = *src++)) {
		uint8_t d;
		size_t b;
		size_t n;

		if(p+5 >= tsize*8)
		       return -1;

		if(isspace(ch))
			continue;

		if(ch >= '0' && ch <= '9')
			d=ch-'0';
		else if(ch >= 'A' && ch <= 'V')
			d=ch-'A'+10;
		else if(ch >= 'a' && ch <= 'v')
			d=ch-'a'+10;
		else
			return -1;

		b=7-p%8;
		n=p/8;

		if(b >= 4)
			target[n]|=d << (b-4);
		else {
			target[n]|=d >> (4-b);
			target[n+1]|=d << (b+4);
		}
		p+=5;
	}
	return (p+7)/8;
}

#ifdef TESTB32

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
	char	 tmp[129];
}

#endif


