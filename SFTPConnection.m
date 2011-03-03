#import "SFTPConnection.h"
#import "ViError.h"
#import "logging.h"

#include "sys_queue.h"
#include <sys/socket.h>

#include <uuid/uuid.h>
#include <vis.h>

#include "log.h"
#include "xmalloc.h"

@implementation SFTPDirectoryEntry
@synthesize filename;
- (SFTPDirectoryEntry *)initWithFilename:(const char *)aFilename attributes:(Attrib *)a
{
	self = [super init];
	if (self)
	{
		filename = [NSString stringWithCString:aFilename encoding:NSUTF8StringEncoding]; // XXX: what encoding?
		bcopy(a, &attributes, sizeof(attributes));
	}
	return self;
}
- (Attrib *)attributes
{
	return &attributes;
}
- (BOOL)isDirectory
{
	return S_ISDIR(attributes.perm);
}
@end

@interface SFTPConnection (Private)
- (void)close;
@end

@implementation SFTPConnection

/* Size of buffer used when copying files */
const size_t copy_buffer_len = 32768;

/* Number of concurrent outstanding requests */
size_t num_requests = 64;

@synthesize host;
@synthesize user;
@synthesize home;

- (void)readStandardError:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSData *data = [userInfo objectForKey:NSFileHandleNotificationDataItem];
	if (data == nil) {
		int err = [[userInfo objectForKey:@"NSFileHandleError"] integerValue];
		INFO(@"error: %s", strerror(err));
		[self close];
	} else if ([data length] == 0) {
		INFO(@"End-of-file on ssh connection %@", [self hostWithUser]);
		[self close];
	} else {
		[stderr appendData:data];
		NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		INFO(@"read data %@", str);

		[[ssh_error fileHandleForReading] readInBackgroundAndNotify];
	}
}

- (SFTPConnection *)initWithHost:(NSString *)hostname user:(NSString *)username error:(NSError **)outError
{
	self = [super init];
	if (self) {
		ssh_task = [[NSTask alloc] init];
		[ssh_task setLaunchPath:@"/usr/bin/ssh"];

		NSMutableArray *arguments = [[NSMutableArray alloc] init];
		[arguments addObject:@"-oForwardX11 no"];
		[arguments addObject:@"-oForwardAgent no"];
		[arguments addObject:@"-oPermitLocalCommand no"];
		[arguments addObject:@"-oClearAllForwardings yes"];
		[arguments addObject:@"-oBatchMode yes"];
		[arguments addObject:@"-oConnectTimeout 10"];
		[arguments addObject:@"-vvv"];
		[arguments addObject:@"-s"];
		if ([username length] > 0)
			[arguments addObject:[NSString stringWithFormat:@"%@@%@", username, hostname]];
		else
			[arguments addObject:hostname];
		[arguments addObject:@"sftp"];

		INFO(@"ssh arguments: %@", arguments);
		[ssh_task setArguments:arguments];

		ssh_input = [NSPipe pipe];
		ssh_output = [NSPipe pipe];
		ssh_error = [NSPipe pipe];

		[ssh_task setStandardInput:ssh_input];
		[ssh_task setStandardOutput:ssh_output];
		[ssh_task setStandardError:ssh_error];

		@try {
			[ssh_task launch];
		}
		@catch (NSException *exception) {
			if (outError)
				*outError = [ViError errorWithObject:exception];
			[self close];
			return nil;
		}

		stderr = [NSMutableData data];
		[[ssh_error fileHandleForReading] readInBackgroundAndNotify];
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(readStandardError:)
							     name:NSFileHandleReadCompletionNotification
							   object:[ssh_error fileHandleForReading]];

		fd_out = [[ssh_input fileHandleForWriting] fileDescriptor];
		fd_in = [[ssh_output fileHandleForReading] fileDescriptor];

		conn = [self initConnectionError:outError];

		if (conn == NULL) {
			[self close];
			return nil;
		}

		host = hostname;
		user = username;
		home = [self currentDirectory];

		directoryCache = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (struct sftp_conn *)initConnectionError:(NSError **)outError
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
		if (outError)
			*outError = [ViError errorWithFormat:@"Invalid packet back from SSH2_FXP_INIT (type %u)", type];
		buffer_free(&msg);
		return(NULL);
	}
	version = buffer_get_int(&msg);

	DEBUG(@"Remote version: %d", version);

	/* Check for extensions */
	while (buffer_len(&msg) > 0) {
		char *name = buffer_get_string(&msg, NULL);
		char *value = buffer_get_string(&msg, NULL);
		int known = 0;

		if (strcmp(name, "posix-rename@openssh.com") == 0 && strcmp(value, "1") == 0) {
			exts |= SFTP_EXT_POSIX_RENAME;
			known = 1;
		} else if (strcmp(name, "statvfs@openssh.com") == 0 && strcmp(value, "2") == 0) {
			exts |= SFTP_EXT_STATVFS;
			known = 1;
		} if (strcmp(name, "fstatvfs@openssh.com") == 0 && strcmp(value, "2") == 0) {
			exts |= SFTP_EXT_FSTATVFS;
			known = 1;
		}

		if (known)
			DEBUG(@"Server supports extension \"%s\" revision %s", name, value);
		else
			DEBUG(@"Unrecognised server extension \"%s\"", name);

		xfree(name);
		xfree(value);
	}

	buffer_free(&msg);

	ret = xmalloc(sizeof(*ret));
	ret->fd_in = fd_in;
	ret->fd_out = fd_out;
	ret->transfer_buflen = copy_buffer_len;
	ret->num_requests = num_requests;
	ret->version = version;
	ret->msg_id = 1;
	ret->exts = exts;

	/* Some filexfer v.0 servers don't support large packets */
	if (version == 0)
		ret->transfer_buflen = MIN(ret->transfer_buflen, 20480);

	return(ret);
}

- (Attrib *)decodeStatRequest:(u_int)expected_id error:(NSError **)outError
{
	Buffer msg;
	u_int type, req_id;
	Attrib *a;

	buffer_init(&msg);
	get_msg(conn->fd_in, &msg);

	type = buffer_get_char(&msg);
	req_id = buffer_get_int(&msg);

	DEBUG(@"Received stat reply T:%u I:%u", type, req_id);
	if (req_id != expected_id) {
		if (outError)
			*outError = [ViError errorWithFormat:@"ID mismatch (%u != %u)", req_id, expected_id];
		[self close];
		return NULL;
	}

	if (type == SSH2_FXP_STATUS) {
		int status = buffer_get_int(&msg);
		if (outError)
			*outError = [ViError errorWithFormat:@"Couldn't stat remote file: %s", fx2txt(status)];
		buffer_free(&msg);
		return NULL;
	} else if (type != SSH2_FXP_ATTRS) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Expected SSH2_FXP_ATTRS(%u) packet, got %u", SSH2_FXP_ATTRS, type];
		[self close];
		return NULL;
	}
	a = decode_attrib(&msg);
	buffer_free(&msg);

	return a;
}

- (Attrib *)stat:(NSString *)path error:(NSError **)outError
{
	u_int req_id = conn->msg_id++;

	const char *utf8path = [path UTF8String];

	send_string_request(conn->fd_out, req_id,
	    conn->version == 0 ? SSH2_FXP_STAT_VERSION_0 : SSH2_FXP_STAT,
	    utf8path, strlen(utf8path));

	return [self decodeStatRequest:req_id error:outError];
}

- (BOOL)isDirectory:(NSString *)path
{
	Attrib *a = [self stat:path error:nil];
	if (a == NULL)
		return NO;
	if (!(a->flags & SSH2_FILEXFER_ATTR_PERMISSIONS))
		return NO;
	return (S_ISDIR(a->perm));
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory error:(NSError **)outError
{
	INFO(@"path = [%@]", path);

	if (path == nil || [path isEqualToString:@""]) {
		/* This is the home directory. */
		if (isDirectory)
			*isDirectory = YES;
		return YES;
	}

	Attrib *a = [self stat:path error:outError];
	if (a == NULL)
		return NO;
	if (!(a->flags & SSH2_FILEXFER_ATTR_PERMISSIONS)) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Permission denied"];
		return NO;
	}
	if (isDirectory)
		*isDirectory = S_ISDIR(a->perm);
	return YES;
}

- (NSArray *)readDirectory:(NSString *)pathS error:(NSError **)outError
{
	Buffer msg;
	u_int count, type, msgid, handle_len, i, expected_id;
	char *handle;

	if (pathS == nil || [pathS isEqualToString:@""]) {
		/* This is the home directory. */
		pathS = [self home];
	}

	const char *path = [pathS UTF8String];
	NSMutableArray *entries = [[NSMutableArray alloc] init];

	msgid = conn->msg_id++;

	buffer_init(&msg);
	buffer_put_char(&msg, SSH2_FXP_OPENDIR);
	buffer_put_int(&msg, msgid);
	buffer_put_cstring(&msg, path);
	send_msg(conn->fd_out, &msg);

	buffer_clear(&msg);

	handle = get_handle(conn->fd_in, msgid, &handle_len, NULL);
	if (handle == NULL)
		return nil;

	for (;;) {
		msgid = expected_id = conn->msg_id++;

		DEBUG(@"Sending SSH2_FXP_READDIR I:%u", msgid);

		buffer_clear(&msg);
		buffer_put_char(&msg, SSH2_FXP_READDIR);
		buffer_put_int(&msg, msgid);
		buffer_put_string(&msg, handle, handle_len);
		send_msg(conn->fd_out, &msg);

		buffer_clear(&msg);

		get_msg(conn->fd_in, &msg);

		type = buffer_get_char(&msg);
		msgid = buffer_get_int(&msg);

		DEBUG(@"Received reply T:%u I:%u", type, msgid);

		if (msgid != expected_id) {
			if (outError)
				*outError = [ViError errorWithFormat:@"ID mismatch (%u != %u)", msgid, expected_id];
			return nil;
		}

		if (type == SSH2_FXP_STATUS) {
			int status = buffer_get_int(&msg);

			DEBUG(@"Received SSH2_FXP_STATUS %d", status);

			if (status == SSH2_FX_EOF) {
				break;
			} else {
				if (outError)
					*outError = [ViError errorWithFormat:@"Couldn't read directory: %s", fx2txt(status)];
				do_close(conn, handle, handle_len);
				xfree(handle);
				return nil;
			}
		} else if (type != SSH2_FXP_NAME) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Expected SSH2_FXP_NAME(%u) packet, got %u", SSH2_FXP_NAME, type];
			return nil;
		}

		count = buffer_get_int(&msg);
		if (count == 0)
			break;
		DEBUG(@"Received %d SSH2_FXP_NAME responses", count);
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
				INFO(@"Server sent suspect path \"%s\" during readdir of \"%s\"", filename, path);
			} else {
				SFTPDirectoryEntry *ent = [[SFTPDirectoryEntry alloc] initWithFilename:filename attributes:a];
				[entries addObject:ent];
			}

			xfree(filename);
			xfree(longname);
		}
	}

	buffer_free(&msg);
	do_close(conn, handle, handle_len);
	xfree(handle);

	return entries;
}


- (void)flushDirectoryCache
{
	directoryCache = [[NSMutableDictionary alloc] init];
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)outError
{
	NSArray *contents = [directoryCache objectForKey:path];
	if (contents == nil) {
		contents = [self readDirectory:path error:outError];
		if (contents)
			[directoryCache setObject:contents forKey:path];
	}
	return contents;
}

- (NSString *)realpath:(NSString *)pathS error:(NSError **)outError
{
	Buffer msg;
	u_int type, expected_id, count, msgid;
	char *filename, *longname;

	const char *path = [pathS UTF8String];

	expected_id = msgid = conn->msg_id++;
	send_string_request(conn->fd_out, msgid, SSH2_FXP_REALPATH, path,
	    strlen(path));

	buffer_init(&msg);

	if (get_msg(conn->fd_in, &msg) != 0)
		return NULL;
	type = buffer_get_char(&msg);
	msgid = buffer_get_int(&msg);

	if (msgid != expected_id) {
		if (outError)
			*outError = [ViError errorWithFormat:@"ID mismatch (%u != %u)", msgid, expected_id];
		return NULL;
	}

	if (type == SSH2_FXP_STATUS) {
		u_int status = buffer_get_int(&msg);

		error("Couldn't canonicalise: %s", fx2txt(status));
		return(NULL);
	} else if (type != SSH2_FXP_NAME) {
		logit("Expected SSH2_FXP_NAME(%u) packet, got %u",
		    SSH2_FXP_NAME, type);
		return NULL;
	}

	count = buffer_get_int(&msg);
	if (count != 1) {
		logit("Got multiple names (%d) from SSH_FXP_REALPATH", count);
		return NULL;
	}

	filename = buffer_get_string(&msg, NULL);
	longname = buffer_get_string(&msg, NULL);
	decode_attrib(&msg);

	DEBUG(@"SSH_FXP_REALPATH %@ -> %s", pathS, filename);

	xfree(longname);

	buffer_free(&msg);

	return [NSString stringWithCString:filename encoding:NSUTF8StringEncoding]; // XXX: encoding?
}

- (NSString *)currentDirectory
{
	return [self realpath:@"." error:nil];
}

- (void)close
{
	INFO(@"Closing connection %d/%d", fd_in, fd_out);
	[ssh_task terminate];
	if (fd_in >= 0)
		close(fd_in);
	if (fd_out >= 0)
		close(fd_out);
	fd_in = fd_out = -1;
	ssh_task = nil;
	ssh_input = ssh_output = ssh_error = nil;
}

- (BOOL)closed
{
	return fd_in == -1;
}

- (NSData *)dataWithContentsOfFile:(NSString *)path error:(NSError **)outError
{
	NSMutableData *output = [NSMutableData data];

	const char *remote_path = [path UTF8String];

	Attrib junk, *a;
	Buffer msg;
	char *handle;
	int status = 0;
	int read_error;
	u_int64_t offset, size;
	u_int handle_len, type, req_id, buflen, num_req, max_req;
	struct request {
		u_int req_id;
		u_int len;
		u_int64_t offset;
		TAILQ_ENTRY(request) tq;
	};
	TAILQ_HEAD(reqhead, request) requests;
	struct request *req;

	TAILQ_INIT(&requests);

	a = [self stat:path error:outError];
	if (a == NULL)
		return nil;
	if (!(a->flags & SSH2_FILEXFER_ATTR_PERMISSIONS)) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Permission denied"];
		return nil;
	}
	if (!S_ISREG(a->perm)) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Not a regular file"];
		return nil;
	}

	if (a->flags & SSH2_FILEXFER_ATTR_SIZE)
		size = a->size;
	else
		size = 0;

	buflen = conn->transfer_buflen;
	buffer_init(&msg);

	/* Send open request */
	req_id = conn->msg_id++;
	buffer_put_char(&msg, SSH2_FXP_OPEN);
	buffer_put_int(&msg, req_id);
	buffer_put_cstring(&msg, remote_path);
	buffer_put_int(&msg, SSH2_FXF_READ);
	attrib_clear(&junk); /* Send empty attributes */
	encode_attrib(&msg, &junk);
	send_msg(conn->fd_out, &msg);
	DEBUG(@"Sent message SSH2_FXP_OPEN I:%u P:%@", req_id, path);

	handle = get_handle(conn->fd_in, req_id, &handle_len, &status);
	if (handle == NULL) {
		buffer_free(&msg);
		if (outError)
			*outError = [ViError errorWithFormat:@"%s", fx2txt(status)];
		return nil;
	}

	/* Read from remote and write to NSData */
	read_error = num_req = offset = 0;
	max_req = 1;

	while (num_req > 0 || max_req > 0) {
		char *data;
		u_int len;

		/* Send some more requests */
		while (num_req < max_req) {
			DEBUG(@"Request range %llu -> %llu (%d/%d)",
			    (unsigned long long)offset,
			    (unsigned long long)offset + buflen - 1,
			    num_req, max_req);
			req = xmalloc(sizeof(*req));
			req->req_id = conn->msg_id++;
			req->len = buflen;
			req->offset = offset;
			offset += buflen;
			num_req++;
			TAILQ_INSERT_TAIL(&requests, req, tq);
			send_read_request(conn->fd_out, req->req_id, req->offset,
			    req->len, handle, handle_len);
		}

		buffer_clear(&msg);
		get_msg(conn->fd_in, &msg);
		type = buffer_get_char(&msg);
		req_id = buffer_get_int(&msg);
		DEBUG(@"Received reply T:%u I:%u R:%d", type, req_id, max_req);

		/* Find the request in our queue */
		for (req = TAILQ_FIRST(&requests);
		    req != NULL && req->req_id != req_id;
		    req = TAILQ_NEXT(req, tq))
			;
		if (req == NULL) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Unexpected reply %u", req_id];
			[self close];
			return nil;
		}

		switch (type) {
		case SSH2_FXP_STATUS:
			status = buffer_get_int(&msg);
			if (status != SSH2_FX_EOF)
				read_error = 1;
			max_req = 0;
			TAILQ_REMOVE(&requests, req, tq);
			xfree(req);
			num_req--;
			break;
		case SSH2_FXP_DATA:
			data = buffer_get_string(&msg, &len);
			DEBUG(@"Received data %llu -> %llu",
			    (unsigned long long)req->offset,
			    (unsigned long long)req->offset + len - 1);
			if (len > req->len) {
				if (outError)
					*outError = [ViError errorWithFormat:@"Received more data than asked for %u > %u", len, req->len];
				[self close];
				return nil;
			}
			[output appendBytes:data length:len];
			xfree(data);

			if (len == req->len) {
				TAILQ_REMOVE(&requests, req, tq);
				xfree(req);
				num_req--;
			} else {
				/* Resend the request for the missing data */
				DEBUG(@"Short data block, re-requesting "
				    "%llu -> %llu (%2d)",
				    (unsigned long long)req->offset + len,
				    (unsigned long long)req->offset +
				    req->len - 1, num_req);
				req->req_id = conn->msg_id++;
				req->len -= len;
				req->offset += len;
				send_read_request(conn->fd_out, req->req_id,
				    req->offset, req->len, handle, handle_len);
				/* Reduce the request size */
				if (len < buflen)
					buflen = MAX(MIN_READ_SIZE, len);
			}
			if (max_req > 0) { /* max_req = 0 iff EOF received */
				if (size > 0 && offset > size) {
					/* Only one request at a time
					 * after the expected EOF */
					DEBUG(@"Finish at %llu (%2d)",
					    (unsigned long long)offset,
					    num_req);
					max_req = 1;
				} else if (max_req <= conn->num_requests) {
					++max_req;
				}
			}
			break;
		default:
			if (outError)
				*outError = [ViError errorWithFormat:@"Expected SSH2_FXP_DATA(%u) packet, got %u", SSH2_FXP_DATA, type];
			[self close];
			return nil;
		}
	}

	/* Sanity check */
	if (TAILQ_FIRST(&requests) != NULL) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Transfer complete, but requests still in queue"];
		[self close];
		return nil;
	}

	if (read_error) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Couldn't read from remote file \"%@\" : %s", path, fx2txt(status)];
		do_close(conn, handle, handle_len);
	} else {
		status = do_close(conn, handle, handle_len);
		if (status != SSH2_FX_OK && outError)
			*outError = [ViError errorWithFormat:@"Couldn't properly close file \"%@\" : %s", path, fx2txt(status)];
	}

	buffer_free(&msg);
	xfree(handle);

	return output;
}

- (NSString *)randomFileAtDirectory:(NSString *)aDirectory
{
	char remote_temp_file[37];
	NSString *remote_temp_path = nil;
	do
	{
		uuid_t uuid;
		uuid_generate(uuid);
		uuid_unparse(uuid, remote_temp_file);
		remote_temp_path = [aDirectory stringByAppendingPathComponent:[NSString stringWithUTF8String:remote_temp_file]];
	} while ([self stat:remote_temp_path error:nil] != NULL);

	return remote_temp_path;
}

- (BOOL)uploadData:(NSData *)data toFile:(NSString *)path withAttributes:(Attrib *)remote_attribs error:(NSError **)outError
{
	NSUInteger dataOffset = 0;
	const void *bytes;

	int status = SSH2_FX_OK;
	u_int handle_len, req_id, type;
	off_t offset;
	char *handle;
	Buffer msg;
	Attrib a;
	u_int32_t startid;
	u_int32_t ackid;
	struct outstanding_ack {
		u_int req_id;
		u_int len;
		off_t offset;
		TAILQ_ENTRY(outstanding_ack) tq;
	};
	TAILQ_HEAD(, outstanding_ack) acks;
	struct outstanding_ack *ack = NULL;

	TAILQ_INIT(&acks);

	if (remote_attribs == NULL) {
		attrib_clear(&a);
		remote_attribs = &a;
	}

	remote_attribs->flags &= ~SSH2_FILEXFER_ATTR_SIZE;
	remote_attribs->flags &= ~SSH2_FILEXFER_ATTR_UIDGID;
	remote_attribs->perm &= 0777;
	remote_attribs->flags &= ~SSH2_FILEXFER_ATTR_ACMODTIME;

	buffer_init(&msg);

	/* Send open request */
	req_id = conn->msg_id++;
	buffer_put_char(&msg, SSH2_FXP_OPEN);
	buffer_put_int(&msg, req_id);
	buffer_put_cstring(&msg, [path fileSystemRepresentation]);
	buffer_put_int(&msg, SSH2_FXF_WRITE|SSH2_FXF_CREAT|SSH2_FXF_TRUNC);
	encode_attrib(&msg, remote_attribs);
	send_msg(conn->fd_out, &msg);
	DEBUG(@"Sent message SSH2_FXP_OPEN I:%u P:%@", req_id, path);

	buffer_clear(&msg);

	handle = get_handle(conn->fd_in, req_id, &handle_len, &status);
	if (handle == NULL) {
		buffer_free(&msg);
		if (outError)
			*outError = [ViError errorWithFormat:@"%s", fx2txt(status)];
		return NO;
	}

	startid = ackid = req_id + 1;

	/* Read from NSData and write to remote */
	offset = 0;

	for (;;) {
		int len;

		/*
		 * Can't use atomicio here because it returns 0 on EOF,
		 * thus losing the last block of the file.
		 */
		if (status != SSH2_FX_OK)
			len = 0;
		else {
			len = conn->transfer_buflen;
			if (dataOffset + len > [data length])
				len = [data length]- dataOffset;
			bytes = [data bytes] + dataOffset;
			dataOffset += len;
		}

		if (len != 0) {
			ack = xmalloc(sizeof(*ack));
			ack->req_id = ++req_id;
			ack->offset = offset;
			ack->len = len;
			TAILQ_INSERT_TAIL(&acks, ack, tq);

			buffer_clear(&msg);
			buffer_put_char(&msg, SSH2_FXP_WRITE);
			buffer_put_int(&msg, ack->req_id);
			buffer_put_string(&msg, handle, handle_len);
			buffer_put_int64(&msg, offset);
			buffer_put_string(&msg, bytes, len);
			send_msg(conn->fd_out, &msg);
			DEBUG(@"Sent message SSH2_FXP_WRITE I:%u O:%llu S:%u",
			    req_id, (unsigned long long)offset, len);
		} else if (TAILQ_FIRST(&acks) == NULL)
			break;

		if (ack == NULL) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Unexpected ACK %u", req_id];
			goto fail;
		}

		if (req_id == startid || len == 0 ||
		    req_id - ackid >= conn->num_requests) {
			u_int r_id;

			buffer_clear(&msg);
			get_msg(conn->fd_in, &msg);
			type = buffer_get_char(&msg);
			r_id = buffer_get_int(&msg);

			if (type != SSH2_FXP_STATUS) {
				if (outError)
					*outError = [ViError errorWithFormat:@"Expected SSH2_FXP_STATUS(%d) packet, got %d", SSH2_FXP_STATUS, type];
				goto fail;
			}

			status = buffer_get_int(&msg);
			DEBUG(@"SSH2_FXP_STATUS %d", status);

			/* Find the request in our queue */
			for (ack = TAILQ_FIRST(&acks);
			    ack != NULL && ack->req_id != r_id;
			    ack = TAILQ_NEXT(ack, tq))
				;
			if (ack == NULL) {
				if (outError)
					*outError = [ViError errorWithFormat:@"Can't find request for ID %u", r_id];
				goto fail;
			}
			TAILQ_REMOVE(&acks, ack, tq);
			DEBUG(@"In write loop, ack for %u %u bytes at %lld",
			    ack->req_id, ack->len, (long long)ack->offset);
			++ackid;
			xfree(ack);
		}
		offset += len;
		if (offset < 0) {
			if (outError)
				*outError = [ViError errorWithFormat:@"offset < 0 while uploading."];
			goto fail;
		}
	}
	buffer_free(&msg);

	if (status != SSH2_FX_OK) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Couldn't write to remote file \"%@\": %s", path, fx2txt(status)];
		goto fail;
	}

	goto done;

fail:
	status = -1;
done:
	if (do_close(conn, handle, handle_len) != SSH2_FX_OK) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Failed to close file."];
		status = -1;
	}
	xfree(handle);

	return status == 0 ? YES : NO;
}

// int do_rm(struct sftp_conn *conn, const char *path)
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)outError
{
	u_int status, req_id;

	const char *utf8path = [path UTF8String];
	DEBUG(@"Sending SSH2_FXP_REMOVE \"%@\"", path);

	req_id = conn->msg_id++;
	send_string_request(conn->fd_out, req_id, SSH2_FXP_REMOVE, utf8path, strlen(utf8path));
	status = get_status(conn->fd_in, req_id);
	if (status != SSH2_FX_OK) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Couldn't delete file: %s", fx2txt(status)];
		return NO;
	}
	return YES;
}

- (BOOL)renameItemAtPath:(NSString *)oldPath toPath:(NSString *)newPath error:(NSError **)outError
{
	Buffer msg;
	u_int status, req_id;

	buffer_init(&msg);

	/* Send rename request */
	req_id = conn->msg_id++;
	if ((conn->exts & SFTP_EXT_POSIX_RENAME)) {
		buffer_put_char(&msg, SSH2_FXP_EXTENDED);
		buffer_put_int(&msg, req_id);
		buffer_put_cstring(&msg, "posix-rename@openssh.com");
	} else {
		buffer_put_char(&msg, SSH2_FXP_RENAME);
		buffer_put_int(&msg, req_id);
	}
	buffer_put_cstring(&msg, [oldPath UTF8String]);
	buffer_put_cstring(&msg, [newPath UTF8String]);
	send_msg(conn->fd_out, &msg);
/*	DEBUG(@"Sent message %s \"%s\" -> \"%s\"",
	    (conn->exts & SFTP_EXT_POSIX_RENAME) ? "posix-rename@openssh.com" :
	    "SSH2_FXP_RENAME", oldPath, newPath);
 */
	buffer_free(&msg);

	status = get_status(conn->fd_in, req_id);
	if (status != SSH2_FX_OK) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Couldn't rename file \"%@\" to \"%@\": %s", oldPath, newPath, fx2txt(status)];
		return NO;
	}

	return YES;
}

- (BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)outError
{
	Attrib *attr = [self stat:path error:nil];

	if (attr == NULL) {
		/* New file. */
		return [self uploadData:data toFile:path withAttributes:attr error:outError];
	}

	NSString *tmp = [self randomFileAtDirectory:[path stringByDeletingLastPathComponent]];

	if (![self uploadData:data toFile:tmp withAttributes:attr error:outError])
		return NO;

	if (sftp_has_posix_rename(conn)) {
		/*
		 * With POSIX rename support, we're guaranteed to be able to atomically replace the file.
		 */
		return [self renameItemAtPath:tmp toPath:path error:outError];
	} else {
		/*
		 * Without POSIX rename support, first move away the existing file, rename our temporary file
		 * to correct name, and finally delete the moved away original file.
		 */
		NSString *tmp2 = [self randomFileAtDirectory:[path stringByDeletingLastPathComponent]];
		if ([self renameItemAtPath:path toPath:tmp2 error:outError] &&
		    [self renameItemAtPath:tmp toPath:path error:outError] &&
		    [self removeItemAtPath:tmp2 error:outError])
			return YES;
	}

	return NO;
}

- (NSString *)hostWithUser
{
	if (user)
		return [NSString stringWithFormat:@"%@@%@", user, host];
	return host;
}

- (NSString *)stderr
{
	NSString *str;
	char *buf;

	str = [[NSString alloc] initWithData:stderr encoding:NSUTF8StringEncoding];
	if (str)
		return str;

	/* Not valid UTF-8, convert to ASCII */

	if ((buf = malloc(4 * [stderr length] + 1)) == NULL) {
		return @"";
	}

	strvisx(buf, [stderr bytes], [stderr length], VIS_NOSLASH);
	str = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
	free(buf);
	return str;
}

@end

