/* $OpenBSD: sftp-client.h,v 1.17 2008/06/08 20:15:29 dtucker Exp $ */

/*
 * Copyright (c) 2001-2004 Damien Miller <djm@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* Client side of SSH2 filexfer protocol */

#ifndef _SFTP_CLIENT_H
#define _SFTP_CLIENT_H

/* Minimum amount of data to read at a time */
#define MIN_READ_SIZE	512

struct sftp_conn {
	int fd_in;
	int fd_out;
	u_int transfer_buflen;
	u_int num_requests;
	u_int version;
	u_int msg_id;
#define SFTP_EXT_POSIX_RENAME	0x00000001
#define SFTP_EXT_STATVFS	0x00000002
#define SFTP_EXT_FSTATVFS	0x00000004
	u_int exts;
};

/*
 * Used for statvfs responses on the wire from the server, because the
 * server's native format may be larger than the client's.
 */
struct sftp_statvfs {
	u_int64_t f_bsize;
	u_int64_t f_frsize;
	u_int64_t f_blocks;
	u_int64_t f_bfree;
	u_int64_t f_bavail;
	u_int64_t f_files;
	u_int64_t f_ffree;
	u_int64_t f_favail;
	u_int64_t f_fsid;
	u_int64_t f_flag;
	u_int64_t f_namemax;
};

void send_msg(int fd, Buffer *m);
int get_msg(int fd, Buffer *m);
char *get_handle(int fd, u_int expected_id, u_int *len, int *ret_status);
void send_read_request(int fd_out, u_int id, u_int64_t offset, u_int len,
    char *handle, u_int handle_len);
void send_string_request(int fd, u_int id, u_int code, const char *s, u_int len);
u_int get_status(int fd, u_int expected_id);

/*
 * Initialise a SSH filexfer connection. Returns NULL on error or
 * a pointer to a initialized sftp_conn struct on success.
 */
struct sftp_conn *do_init(int, int, u_int, u_int);

u_int sftp_proto_version(struct sftp_conn *);

/* Close file referred to by 'handle' */
int do_close(struct sftp_conn *, char *, u_int);

/* Create directory 'path' */
int do_mkdir(struct sftp_conn *, char *, Attrib *);

/* Remove directory 'path' */
int do_rmdir(struct sftp_conn *, char *);

int sftp_has_posix_rename(struct sftp_conn *conn);

#endif
