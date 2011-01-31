/* $OpenBSD: sftp-client.c,v 1.86 2008/06/26 06:10:09 djm Exp $ */
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

/* XXX: memleaks */
/* XXX: signed vs unsigned */
/* XXX: remove all logging, only return status codes */
/* XXX: copy between two remote sites */

#include <sys/types.h>
#include <sys/queue.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/param.h>
#include <sys/statvfs.h>
#include <sys/uio.h>

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdarg.h>

#include "xmalloc.h"
#include "buffer.h"
#include "log.h"
#include "atomicio.h"
#include "misc.h"

#include "sftp.h"
#include "sftp-common.h"
#include "sftp-client.h"

void
send_msg(int fd, Buffer *m)
{
	u_char mlen[4];
	struct iovec iov[2];

	if (buffer_len(m) > SFTP_MAX_MSG_LENGTH)
		fatal("Outbound message too long %u", buffer_len(m));

	/* Send length first */
	put_u32(mlen, buffer_len(m));
	iov[0].iov_base = mlen;
	iov[0].iov_len = sizeof(mlen);
	iov[1].iov_base = buffer_ptr(m);
	iov[1].iov_len = buffer_len(m);

	if (atomiciov(writev, fd, iov, 2) != buffer_len(m) + sizeof(mlen))
		fatal("Couldn't send packet: %s", strerror(errno));

	buffer_clear(m);
}

int
get_msg(int fd, Buffer *m)
{
	u_int msg_len;

	buffer_append_space(m, 4);
	if (atomicio(read, fd, buffer_ptr(m), 4) != 4) {
		if (errno == EPIPE)
			logit("Connection closed");
		else
			logit("Couldn't read packet: %s", strerror(errno));
		return -1;
	}

	msg_len = buffer_get_int(m);
	if (msg_len > SFTP_MAX_MSG_LENGTH)
		fatal("Received message too long %u", msg_len);

	buffer_append_space(m, msg_len);
	if (atomicio(read, fd, buffer_ptr(m), msg_len) != msg_len) {
		if (errno == EPIPE)
			logit("Connection closed");
		else
			logit("Read packet: %s", strerror(errno));
		return -1;
	}
	return 0;
}

void
send_string_request(int fd, u_int id, u_int code, const char *s,
    u_int len)
{
	Buffer msg;

	buffer_init(&msg);
	buffer_put_char(&msg, code);
	buffer_put_int(&msg, id);
	buffer_put_string(&msg, s, len);
	send_msg(fd, &msg);
	debug3("Sent message fd %d T:%u I:%u", fd, code, id);
	buffer_free(&msg);
}

static void
send_string_attrs_request(int fd, u_int id, u_int code, char *s,
    u_int len, Attrib *a)
{
	Buffer msg;

	buffer_init(&msg);
	buffer_put_char(&msg, code);
	buffer_put_int(&msg, id);
	buffer_put_string(&msg, s, len);
	encode_attrib(&msg, a);
	send_msg(fd, &msg);
	debug3("Sent message fd %d T:%u I:%u", fd, code, id);
	buffer_free(&msg);
}

u_int
get_status(int fd, u_int expected_id)
{
	Buffer msg;
	u_int type, id, status;

	buffer_init(&msg);
	if (get_msg(fd, &msg) != 0)
		return 255;
	type = buffer_get_char(&msg);
	id = buffer_get_int(&msg);

	if (id != expected_id)
	{
		logit("ID mismatch (%u != %u)", id, expected_id);
		return 255;
	}
	if (type != SSH2_FXP_STATUS)
	{
		logit("Expected SSH2_FXP_STATUS(%u) packet, got %u",
		    SSH2_FXP_STATUS, type);
		return 255;
	}

	status = buffer_get_int(&msg);
	buffer_free(&msg);

	debug3("SSH2_FXP_STATUS %u", status);

	return(status);
}

char *
get_handle(int fd, u_int expected_id, u_int *len, int *ret_status)
{
	Buffer msg;
	u_int type, id;
	char *handle;

	buffer_init(&msg);
	get_msg(fd, &msg);
	type = buffer_get_char(&msg);
	id = buffer_get_int(&msg);

	if (id != expected_id)
		fatal("ID mismatch (%u != %u)", id, expected_id);
	if (type == SSH2_FXP_STATUS) {
		int status = buffer_get_int(&msg);

		error("Couldn't get handle: %s", fx2txt(status));
		if (ret_status)
			*ret_status = status;
		buffer_free(&msg);
		return(NULL);
	} else if (type != SSH2_FXP_HANDLE)
		fatal("Expected SSH2_FXP_HANDLE(%u) packet, got %u",
		    SSH2_FXP_HANDLE, type);

	handle = buffer_get_string(&msg, len);
	buffer_free(&msg);

	return(handle);
}

struct sftp_conn *
do_init(int fd_in, int fd_out, u_int transfer_buflen, u_int num_requests)
{
	u_int type, exts = 0;
	int version;
	Buffer msg;
	struct sftp_conn *ret;

	buffer_init(&msg);
	buffer_put_char(&msg, SSH2_FXP_INIT);
	buffer_put_int(&msg, SSH2_FILEXFER_VERSION);
	send_msg(fd_out, &msg);

	buffer_clear(&msg);

	if (get_msg(fd_in, &msg) != 0)
		return NULL;

	/* Expecting a VERSION reply */
	if ((type = buffer_get_char(&msg)) != SSH2_FXP_VERSION) {
		error("Invalid packet back from SSH2_FXP_INIT (type %u)",
		    type);
		buffer_free(&msg);
		return(NULL);
	}
	version = buffer_get_int(&msg);

	debug2("Remote version: %d", version);

	/* Check for extensions */
	while (buffer_len(&msg) > 0) {
		char *name = buffer_get_string(&msg, NULL);
		char *value = buffer_get_string(&msg, NULL);
		int known = 0;

		if (strcmp(name, "posix-rename@openssh.com") == 0 &&
		    strcmp(value, "1") == 0) {
			exts |= SFTP_EXT_POSIX_RENAME;
			known = 1;
		} else if (strcmp(name, "statvfs@openssh.com") == 0 &&
		    strcmp(value, "2") == 0) {
			exts |= SFTP_EXT_STATVFS;
			known = 1;
		} if (strcmp(name, "fstatvfs@openssh.com") == 0 &&
		    strcmp(value, "2") == 0) {
			exts |= SFTP_EXT_FSTATVFS;
			known = 1;
		}
		if (known) {
			debug2("Server supports extension \"%s\" revision %s",
			    name, value);
		} else {
			debug2("Unrecognised server extension \"%s\"", name);
		}
		xfree(name);
		xfree(value);
	}

	buffer_free(&msg);

	ret = xmalloc(sizeof(*ret));
	ret->fd_in = fd_in;
	ret->fd_out = fd_out;
	ret->transfer_buflen = transfer_buflen;
	ret->num_requests = num_requests;
	ret->version = version;
	ret->msg_id = 1;
	ret->exts = exts;

	/* Some filexfer v.0 servers don't support large packets */
	if (version == 0)
		ret->transfer_buflen = MIN(ret->transfer_buflen, 20480);

	return(ret);
}

u_int
sftp_proto_version(struct sftp_conn *conn)
{
	return(conn->version);
}

int
do_close(struct sftp_conn *conn, char *handle, u_int handle_len)
{
	u_int id, status;
	Buffer msg;

	buffer_init(&msg);

	id = conn->msg_id++;
	buffer_put_char(&msg, SSH2_FXP_CLOSE);
	buffer_put_int(&msg, id);
	buffer_put_string(&msg, handle, handle_len);
	send_msg(conn->fd_out, &msg);
	debug3("Sent message SSH2_FXP_CLOSE I:%u", id);

	status = get_status(conn->fd_in, id);
	if (status != SSH2_FX_OK)
		error("Couldn't close file: %s", fx2txt(status));

	buffer_free(&msg);

	return(status);
}


int
do_readdir(struct sftp_conn *conn, const char *path, SFTP_DIRENT ***dir)
{
	Buffer msg;
	u_int count, type, id, handle_len, i, expected_id, ents = 0;
	char *handle;

	id = conn->msg_id++;

	buffer_init(&msg);
	buffer_put_char(&msg, SSH2_FXP_OPENDIR);
	buffer_put_int(&msg, id);
	buffer_put_cstring(&msg, path);
	send_msg(conn->fd_out, &msg);

	buffer_clear(&msg);

	handle = get_handle(conn->fd_in, id, &handle_len, NULL);
	if (handle == NULL)
		return(-1);

	if (dir) {
		ents = 0;
		*dir = xmalloc(sizeof(**dir));
		(*dir)[0] = NULL;
	}

	for (; !interrupted;) {
		id = expected_id = conn->msg_id++;

		debug3("Sending SSH2_FXP_READDIR I:%u", id);

		buffer_clear(&msg);
		buffer_put_char(&msg, SSH2_FXP_READDIR);
		buffer_put_int(&msg, id);
		buffer_put_string(&msg, handle, handle_len);
		send_msg(conn->fd_out, &msg);

		buffer_clear(&msg);

		get_msg(conn->fd_in, &msg);

		type = buffer_get_char(&msg);
		id = buffer_get_int(&msg);

		debug3("Received reply T:%u I:%u", type, id);

		if (id != expected_id)
			fatal("ID mismatch (%u != %u)", id, expected_id);

		if (type == SSH2_FXP_STATUS) {
			int status = buffer_get_int(&msg);

			debug3("Received SSH2_FXP_STATUS %d", status);

			if (status == SSH2_FX_EOF) {
				break;
			} else {
				error("Couldn't read directory: %s",
				    fx2txt(status));
				do_close(conn, handle, handle_len);
				xfree(handle);
				return(status);
			}
		} else if (type != SSH2_FXP_NAME)
			fatal("Expected SSH2_FXP_NAME(%u) packet, got %u",
			    SSH2_FXP_NAME, type);

		count = buffer_get_int(&msg);
		if (count == 0)
			break;
		debug3("Received %d SSH2_FXP_NAME responses", count);
		for (i = 0; i < count; i++) {
			char *filename, *longname;
			Attrib *a;

			filename = buffer_get_string(&msg, NULL);
			longname = buffer_get_string(&msg, NULL);
			a = decode_attrib(&msg);

			/*
			 * Directory entries should never contain '/'
			 * These can be used to attack recursive ops
			 * (e.g. send '../../../../etc/passwd')
			 */
			if (strchr(filename, '/') != NULL) {
				error("Server sent suspect path \"%s\" "
				    "during readdir of \"%s\"", filename, path);
				goto next;
			}

			if (dir) {
				*dir = xrealloc(*dir, ents + 2, sizeof(**dir));
				(*dir)[ents] = xmalloc(sizeof(***dir));
				(*dir)[ents]->filename = xstrdup(filename);
				(*dir)[ents]->longname = xstrdup(longname);
				memcpy(&(*dir)[ents]->a, a, sizeof(*a));
				(*dir)[++ents] = NULL;
			}
next:
			xfree(filename);
			xfree(longname);
		}
	}

	buffer_free(&msg);
	do_close(conn, handle, handle_len);
	xfree(handle);

	/* Don't return partial matches on interrupt */
	if (interrupted && dir != NULL && *dir != NULL) {
		free_sftp_dirents(*dir);
		*dir = xmalloc(sizeof(**dir));
		**dir = NULL;
	}

	return(0);
}

void
free_sftp_dirents(SFTP_DIRENT **s)
{
	int i;

	for (i = 0; s[i]; i++) {
		xfree(s[i]->filename);
		xfree(s[i]->longname);
		xfree(s[i]);
	}
	xfree(s);
}

int
do_mkdir(struct sftp_conn *conn, char *path, Attrib *a)
{
	u_int status, id;

	id = conn->msg_id++;
	send_string_attrs_request(conn->fd_out, id, SSH2_FXP_MKDIR, path,
	    strlen(path), a);

	status = get_status(conn->fd_in, id);
	if (status != SSH2_FX_OK)
		error("Couldn't create directory: %s", fx2txt(status));

	return(status);
}

int
do_rmdir(struct sftp_conn *conn, char *path)
{
	u_int status, id;

	id = conn->msg_id++;
	send_string_request(conn->fd_out, id, SSH2_FXP_RMDIR, path,
	    strlen(path));

	status = get_status(conn->fd_in, id);
	if (status != SSH2_FX_OK)
		error("Couldn't remove directory: %s", fx2txt(status));

	return(status);
}

char *
do_realpath(struct sftp_conn *conn, char *path)
{
	Buffer msg;
	u_int type, expected_id, count, id;
	char *filename, *longname;

	expected_id = id = conn->msg_id++;
	send_string_request(conn->fd_out, id, SSH2_FXP_REALPATH, path,
	    strlen(path));

	buffer_init(&msg);

	if (get_msg(conn->fd_in, &msg) != 0)
		return NULL;
	type = buffer_get_char(&msg);
	id = buffer_get_int(&msg);

	if (id != expected_id)
	{
		logit("ID mismatch (%u != %u)", id, expected_id);
		return NULL;
	}

	if (type == SSH2_FXP_STATUS) {
		u_int status = buffer_get_int(&msg);

		error("Couldn't canonicalise: %s", fx2txt(status));
		return(NULL);
	} else if (type != SSH2_FXP_NAME)
	{
		logit("Expected SSH2_FXP_NAME(%u) packet, got %u",
		    SSH2_FXP_NAME, type);
		return NULL;
	}

	count = buffer_get_int(&msg);
	if (count != 1)
	{
		logit("Got multiple names (%d) from SSH_FXP_REALPATH", count);
		return NULL;
	}

	filename = buffer_get_string(&msg, NULL);
	longname = buffer_get_string(&msg, NULL);
	decode_attrib(&msg);

	debug3("SSH_FXP_REALPATH %s -> %s", path, filename);

	xfree(longname);

	buffer_free(&msg);

	return(filename);
}

void
send_read_request(int fd_out, u_int id, u_int64_t offset, u_int len,
    char *handle, u_int handle_len)
{
	Buffer msg;

	buffer_init(&msg);
	buffer_clear(&msg);
	buffer_put_char(&msg, SSH2_FXP_READ);
	buffer_put_int(&msg, id);
	buffer_put_string(&msg, handle, handle_len);
	buffer_put_int64(&msg, offset);
	buffer_put_int(&msg, len);
	send_msg(fd_out, &msg);
	buffer_free(&msg);
}

int
sftp_has_posix_rename(struct sftp_conn *conn)
{
	return ((conn->exts & SFTP_EXT_POSIX_RENAME) == SFTP_EXT_POSIX_RENAME);
}

