#import "SFTPConnection.h"
#import "ViError.h"
#import "ViRegexp.h"

#include "sys_queue.h"
#include <sys/socket.h>

#include <uuid/uuid.h>
#include <vis.h>

#include "logging.h"

void	 hexdump(void *data, size_t len, const char *fmt, ...);

/* Convert from SSH2_FX_ status to text error message */
static const char *
fx2txt(int status)
{
	switch (status) {
	case SSH2_FX_OK:
		return("No error");
	case SSH2_FX_EOF:
		return("End of file");
	case SSH2_FX_NO_SUCH_FILE:
		return("No such file or directory");
	case SSH2_FX_PERMISSION_DENIED:
		return("Permission denied");
	case SSH2_FX_FAILURE:
		return("Failure");
	case SSH2_FX_BAD_MESSAGE:
		return("Bad message");
	case SSH2_FX_NO_CONNECTION:
		return("No connection");
	case SSH2_FX_CONNECTION_LOST:
		return("Connection lost");
	case SSH2_FX_OP_UNSUPPORTED:
		return("Operation unsupported");
	case SSH2_FX_INVALID_HANDLE:
		return("Invalid handle");
	case SSH2_FX_NO_SUCH_PATH:
		return("No such path");
	case SSH2_FX_FILE_ALREADY_EXISTS:
		return("File already exists");
	case SSH2_FX_WRITE_PROTECT:
		return("Media is write-protected");
	case SSH2_FX_NO_MEDIA:
		return("No media available");
	case SSH2_FX_NO_SPACE_ON_FILESYSTEM:
		return("No space left on device");
	case SSH2_FX_QUOTA_EXCEEDED:
		return("Quota exceeded");
	case SSH2_FX_UNKNOWN_PRINCIPLE:
		return("Unknown principle");
	case SSH2_FX_LOCK_CONFlICT:
		return("Lock conflict");
	default:
		return("Unknown status");
	}
	/* NOTREACHED */
}

/* Convert from SSH2_FXP_ requests to text error message */
static const char *
req2txt(int type)
{
#define FXPREQ(t) case t: return #t; break
	switch (type) {
	FXPREQ(SSH2_FXP_INIT);
	FXPREQ(SSH2_FXP_OPEN);
	FXPREQ(SSH2_FXP_CLOSE);
	FXPREQ(SSH2_FXP_READ);
	FXPREQ(SSH2_FXP_WRITE);
	FXPREQ(SSH2_FXP_LSTAT);
	// FXPREQ(SSH2_FXP_STAT_VERSION_0);
	FXPREQ(SSH2_FXP_FSTAT);
	FXPREQ(SSH2_FXP_SETSTAT);
	FXPREQ(SSH2_FXP_FSETSTAT);
	FXPREQ(SSH2_FXP_OPENDIR);
	FXPREQ(SSH2_FXP_READDIR);
	FXPREQ(SSH2_FXP_REMOVE);
	FXPREQ(SSH2_FXP_MKDIR);
	FXPREQ(SSH2_FXP_RMDIR);
	FXPREQ(SSH2_FXP_REALPATH);
	FXPREQ(SSH2_FXP_STAT);
	FXPREQ(SSH2_FXP_RENAME);
	FXPREQ(SSH2_FXP_READLINK);
	FXPREQ(SSH2_FXP_SYMLINK);
	FXPREQ(SSH2_FXP_EXTENDED);
	default:
		return("Unknown request");
	}
	/* NOTREACHED */
}

/* Convert from SSH2_FXP_ responses to text error message */
static const char *
resp2txt(int type)
{
#define FXPRESP(t) case t: return #t; break
	switch (type) {
	FXPRESP(SSH2_FXP_VERSION);
	FXPRESP(SSH2_FXP_STATUS);
	FXPRESP(SSH2_FXP_HANDLE);
	FXPRESP(SSH2_FXP_DATA);
	FXPRESP(SSH2_FXP_NAME);
	FXPRESP(SSH2_FXP_ATTRS);
	FXPRESP(SSH2_FXP_EXTENDED_REPLY);
	default:
		return("Unknown response");
	}
	/* NOTREACHED */
}


@implementation SFTPRequest

@synthesize onResponse = responseCallback;
@synthesize onCancel = cancelCallback;
@synthesize cancelled;
@synthesize requestId;
@synthesize subRequest;
@synthesize progress;
@synthesize delegate;
@synthesize waitRequest;

+ (SFTPRequest *)requestWithId:(uint32_t)reqId
			ofType:(uint32_t)type
		  onConnection:(SFTPConnection *)aConnection
{
	return [[SFTPRequest alloc] initWithId:reqId
					ofType:type
				  onConnection:aConnection];
}

- (SFTPRequest *)initWithId:(uint32_t)reqId
		     ofType:(uint32_t)type
	       onConnection:(SFTPConnection *)aConnection
{
	if ((self = [super init]) != nil) {
		requestId = reqId;
		requestType = type;
		connection = aConnection;
	}
	return self;
}

- (void)response:(SFTPMessage *)msg
{
	BOOL gotWaitResponse = NO;
	if (waitRequest && (waitRequest == self || waitRequest.subRequest == self)) {
		gotWaitResponse = YES;
		DEBUG(@"got wait response %@ for %@", msg, waitRequest);
	}

	if (responseCallback)
		responseCallback(msg);
	else
		DEBUG(@"NULL response callback for request id %u", requestId);
	finished = YES;

	if (gotWaitResponse) {
		if (waitRequest.subRequest) {
			waitRequest.subRequest.waitRequest = waitRequest;
		} else {
			DEBUG(@"stopping wait request %@", waitRequest);
			[NSApp abortModal];
		}
	} else
		DEBUG(@"no wait request for request %@", self);
}

- (void)cancel
{
	if (cancelled) {
		INFO(@"%@ already cancelled", self);
		return;
	}

	DEBUG(@"cancelling request %@", self);
	cancelled = YES;
	finished = YES;
	[connection dequeueRequest:requestId];

	if (cancelCallback) {
		DEBUG(@"running cancel callback %p", cancelCallback);
		cancelCallback(self);
	}

	/* If this request has subrequests, cancel them too. */
	if (subRequest) {
		[subRequest cancel];
		subRequest = nil;
	}

	if (waitWindow) {
		DEBUG(@"aborting wait window %@", waitWindow);
		[NSApp abortModal];
	}
}

- (IBAction)cancelDeferred:(id)sender
{
	DEBUG(@"cancelling wait window %@ with code 2", waitWindow);
	[NSApp stopModalWithCode:2];
}

- (void)waitInWindow:(NSWindow *)window message:(NSString *)waitMessage
{
	waitRequest = self;

	/* Run and block the UI for 2 seconds. */
	NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:2.0];
	while ([limitDate timeIntervalSinceNow] > 0) {
		if (finished)
			return;
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:limitDate];
	}

	DEBUG(@"limitdate %@ reached, presenting cancellable sheet", limitDate);

	/* Continue with a sheet with a cancel button. */
	[NSBundle loadNibNamed:@"WaitProgress" owner:self];
	[waitLabel setStringValue:waitMessage];
	[progressIndicator startAnimation:nil];
	[waitWindow setTitle:[NSString stringWithFormat:@"Waiting on %@", connection.title]];

	NSInteger reason = [NSApp runModalForWindow:waitWindow];

	DEBUG(@"wait window %@ done with reason %li", waitWindow, reason);
	[progressIndicator stopAnimation:nil];
	[waitWindow orderOut:nil];
	waitWindow = nil;

	if (reason == 2)
		[self cancel];

	/* Wait for subrequests. */
	while (subRequest && !cancelled) {
		DEBUG(@"waiting for subrequest %@", subRequest);
		SFTPRequest *req = subRequest;
		[req waitInWindow:window message:waitMessage];
		if (subRequest == req) {
			DEBUG(@"Warning: request %@ didn't reset subRequest after %@", self, req);
			break;
		}
	}

	DEBUG(@"request %@ is finished", self);
}

- (void)wait
{
	while (!finished) {
		DEBUG(@"request %@ not finished yet", self);
		[[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}

	while (subRequest && !cancelled) {
		DEBUG(@"waiting for subrequest %@", subRequest);
		SFTPRequest *req = subRequest;
		[req wait];
		if (subRequest == req) {
			DEBUG(@"Warning: request %@ didn't reset subRequest after %@", self, req);
			break;
		}
	}

	DEBUG(@"request %@ is finished", self);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<SFTPRequest %s, id %u>",
	    req2txt(requestType), requestId];
}

@end


#pragma mark -


@implementation SFTPMessage

@synthesize type, requestId, data;

+ (SFTPMessage *)messageWithData:(NSData *)someData
{
	return [[SFTPMessage alloc] initWithData:someData];
}

- (SFTPMessage *)initWithData:(NSData *)someData
{
	if ((self = [super init]) != nil) {
		data = someData;
		ptr = [data bytes];
		if (![self getByte:&type] ||
		    ![self getUnsigned:&requestId])
			return nil;
	}
	return self;
}

- (NSInteger)left
{
	return [data length] - (ptr - [data bytes]);
}

- (void)reset
{
	ptr = [data bytes];
}

- (BOOL)getStringNoCopy:(NSString **)outString
{
	uint32_t len;
	if (![self getUnsigned:&len] || [self left] < len)
		return NO;

	if (outString) {
		NSString *str = [[NSString alloc] initWithBytesNoCopy:(void *)ptr
							       length:len
							     encoding:NSUTF8StringEncoding
							 freeWhenDone:NO];
		if (str == nil)
			str = [[NSString alloc] initWithBytesNoCopy:(void *)ptr
							     length:len
							   encoding:NSISOLatin1StringEncoding
						       freeWhenDone:NO];

		*outString = str;
	}

	ptr += len;
	return YES;
}

- (BOOL)getString:(NSString **)outString
{
	uint32_t len;
	if (![self getUnsigned:&len] || [self left] < len)
		return NO;

	if (outString) {
		NSString *str = [[NSString alloc] initWithBytes:(void *)ptr
							 length:len
						       encoding:NSUTF8StringEncoding];
		if (str == nil)
			str = [[NSString alloc] initWithBytes:(void *)ptr
						       length:len
						     encoding:NSISOLatin1StringEncoding];

		*outString = str;
	}

	ptr += len;
	return YES;
}

- (BOOL)getBlob:(NSData **)outData
{
	uint32_t len;
	if (![self getUnsigned:&len] || [self left] < len)
		return NO;
	if (outData)
		*outData = [NSData dataWithBytes:ptr length:len];

	ptr += len;
	return YES;
}

- (BOOL)getByte:(uint8_t *)ret
{
	if ([self left] == 0)
		return NO;
	*ret = *(uint8_t *)ptr++;
	return YES;
}

- (BOOL)getUnsigned:(uint32_t *)ret
{
	if ([self left] < sizeof(uint32_t))
		return NO;

	uint32_t tmp;
	bcopy(ptr, &tmp, sizeof(tmp));
	ptr += sizeof(tmp);
	*ret = CFSwapInt32BigToHost(tmp);
	return YES;
}

- (BOOL)getInt64:(int64_t *)ret;
{
	if ([self left] < sizeof(uint64_t))
		return NO;

	uint64_t tmp;
	bcopy(ptr, &tmp, sizeof(tmp));
	ptr += sizeof(tmp);
	*ret = CFSwapInt64BigToHost(tmp);
	return YES;
}

- (BOOL)expectStatus:(uint32_t)expectedStatus
	       error:(NSError **)outError
{
	uint32_t status = 0;
	NSString *errmsg = nil;
	if (type == SSH2_FXP_STATUS) {
		if ([self getUnsigned:&status] && status == expectedStatus)
			return YES;
		[self getStringNoCopy:&errmsg];
	}

	DEBUG(@"unexpected status code %u (wanted %u)", status, expectedStatus);

	if (outError) {
		if (status != 0) {
			if (errmsg)
				*outError = [ViError errorWithCode:status format:@"%@", errmsg];
			else
				*outError = [ViError errorWithCode:status format:@"%s", fx2txt(status)];
		} else
			*outError = [ViError errorWithFormat:@"SFTP protocol error"];
	}
	return NO;
}

- (BOOL)expectType:(uint32_t)expectedType
	     error:(NSError **)outError
{
	if (type == expectedType)
		return YES;

	DEBUG(@"unexpected type %u (wanted %u)", type, expectedType);
	return [self expectStatus:SSH2_FX_MAX + 1 error:outError]; // expect the impossible
}

- (BOOL)getAttributes:(NSDictionary **)ret
{
	uint32_t	 flags;
	int64_t		 size;
	uint32_t	 uid, gid;
	uint32_t	 perm;
	uint32_t	 atime, mtime;

	if (![self getUnsigned:&flags])
		return NO;

	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

	if (flags & SSH2_FILEXFER_ATTR_SIZE) {
		if (![self getInt64:&size])
			return NO;
		[attributes setObject:[NSNumber numberWithUnsignedLongLong:size] forKey:NSFileSize];
	}

	if (flags & SSH2_FILEXFER_ATTR_UIDGID) {
		if (![self getUnsigned:&uid] || ![self getUnsigned:&gid])
			return NO;
		[attributes setObject:[NSNumber numberWithUnsignedInt:uid] forKey:NSFileOwnerAccountID];
		[attributes setObject:[NSNumber numberWithUnsignedInt:gid] forKey:NSFileGroupOwnerAccountID];
	}

	if (flags & SSH2_FILEXFER_ATTR_PERMISSIONS) {
		if (![self getUnsigned:&perm])
			return NO;
		NSNumber *n = [NSNumber numberWithUnsignedInt:perm];
		DEBUG(@"perms = %06o == %@ ?", perm, n);
		[attributes setObject:n forKey:NSFilePosixPermissions];

		NSString *fileType;
		if (S_ISDIR(perm))
			fileType = NSFileTypeDirectory;
		else if (S_ISLNK(perm))
			fileType = NSFileTypeSymbolicLink;
		else if (S_ISSOCK(perm))
			fileType = NSFileTypeSocket;
		else if (S_ISBLK(perm))
			fileType = NSFileTypeBlockSpecial;
		else if (S_ISCHR(perm))
			fileType = NSFileTypeCharacterSpecial;
		else if (S_ISREG(perm))
			fileType = NSFileTypeRegular;
		else
			fileType = NSFileTypeUnknown;

		[attributes setObject:fileType forKey:NSFileType];
	}

	if (flags & SSH2_FILEXFER_ATTR_ACMODTIME) {
		if (![self getUnsigned:&atime] || ![self getUnsigned:&mtime])
			return NO;
		[attributes setObject:[NSDate dateWithTimeIntervalSince1970:mtime] forKey:NSFileModificationDate];
	}

	/* vendor-specific extensions */
	if (flags & SSH2_FILEXFER_ATTR_EXTENDED) {
		uint32_t i, count;

		if (![self getUnsigned:&count])
			return NO;

		for (i = 0; i < count; i++)
			if (![self getString:NULL] || ![self getString:NULL])
				return NO;
	}

	if (ret)
		*ret = attributes;

	return YES;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<SFTPMessage %s, id %u>", resp2txt(type), requestId];
}

@end


#pragma mark -

@implementation SFTPConnection

/* Max number of concurrent outstanding requests */
#define NUM_REQUESTS 64

@synthesize host;
@synthesize user;
@synthesize home;

- (BOOL)fail:(NSError **)outError with:(NSString *)fmt, ...
{
	if (outError) {
		va_list ap;
		va_start(ap, fmt);
		*outError = [ViError errorWithObject:[[NSString alloc] initWithFormat:fmt arguments:ap]];
		va_end(ap);
	}
	[self close];
	return NO;
}

- (void)reportConnectionStatus:(NSString *)status
{
	DEBUG(@"reporting connection status [%@]", status);
	for (SFTPRequest *req in [requests allValues])
		if ([req.delegate respondsToSelector:@selector(deferred:status:)])
			[req.delegate deferred:req status:status];
	if ([initRequest.delegate respondsToSelector:@selector(deferred:status:)])
		[initRequest.delegate deferred:initRequest status:status];
}

- (SFTPMessage *)readMessage
{
	NSUInteger len = [inbuf length];

	if (len == 0)
		return nil;

	if (len <= sizeof(uint32_t)) {
		DEBUG(@"buffer too small: got %lu bytes, need > 4 bytes", len);
		return nil;
	}

	uint32_t msg_len;
	[inbuf getBytes:&msg_len range:NSMakeRange(0, 4)];
	msg_len = ntohl(msg_len);
	DEBUG(@"message length is %u", msg_len);

	if (msg_len < 5) {
		DEBUG(@"message too small: is %lu bytes, should be >= 5 bytes", msg_len);
		/* Just skip this message and try next. */
		[inbuf replaceBytesInRange:NSMakeRange(0, msg_len + sizeof(uint32_t)) withBytes:NULL length:0];
		return [self readMessage];
	}

	if (len - sizeof(uint32_t) < msg_len) {
		DEBUG(@"buffer too small: got %lu bytes, need %lu bytes", len, msg_len + sizeof(uint32_t));
		return nil;
	}

	NSData *data = [inbuf subdataWithRange:NSMakeRange(sizeof(uint32_t), msg_len)];

	// hexdump([data bytes], msg_len, "raw message bytes:");

	/* Drain the extracted bytes. */
	[inbuf replaceBytesInRange:NSMakeRange(0, msg_len + sizeof(uint32_t)) withBytes:NULL length:0];

	SFTPMessage *msg = [SFTPMessage messageWithData:data];
	return msg;
}

- (void)dispatchMessages
{
	SFTPMessage *msg;
	while ((msg = [self readMessage]) != nil) {
		if (msg.type == SSH2_FXP_VERSION) {
			if (initRequest == nil)
				INFO(@"%s", "spurious version response");
			else
				[initRequest response:msg];
			initRequest = nil;
		} else {
			NSNumber *req_id = [NSNumber numberWithUnsignedInt:msg.requestId];
			SFTPRequest *request = [requests objectForKey:req_id];
			if (request == nil) {
				INFO(@"spurious request id %@", req_id);
				INFO(@"current request queue: %@", requests);
			} else {
				DEBUG(@"got response %@ to request %@", msg, request);
				[request response:msg];
				[requests removeObjectForKey:req_id];
			}
		}
	}
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event
{
	DEBUG(@"got event %lu on stream %@", event, stream);

	NSString *status;
	const void *ptr;
	NSUInteger len;

	switch (event) {
	case NSStreamEventNone:
	case NSStreamEventOpenCompleted:
	default:
		break;
	case NSStreamEventHasBytesAvailable:
		if (stream == sshPipe) {
			[sshPipe getBuffer:&ptr length:&len];
			DEBUG(@"got %lu bytes", len);
			if (len > 0) {
				[inbuf appendBytes:ptr length:len];
				[self dispatchMessages];
			}
		} else if (stream == errStream) {
			[errStream getBuffer:&ptr length:&len];
			DEBUG(@"got %lu bytes", len);
			if (len > 0) {
				[errbuf appendBytes:ptr length:len];

				NSString *str = [[NSString alloc] initWithBytesNoCopy:(void *)ptr
									       length:len
									     encoding:NSISOLatin1StringEncoding
									 freeWhenDone:NO];
				DEBUG(@"read data: [%@]", str);

				NSRange range = NSMakeRange(0, [str length]);
				while (range.length > 0) {
					DEBUG(@"looking for connect messages in range %@", NSStringFromRange(range));
					unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;
					ViRegexp *rx = [[ViRegexp alloc] initWithString:@"^debug1: (Connecting to .*)$"
										options:rx_options];
					ViRegexpMatch *m = [rx matchInString:str range:range];
					if (m == nil) {
						rx = [[ViRegexp alloc] initWithString:@"^debug1: (connect to address .* port .*: .*)$"
									      options:rx_options];
						m = [rx matchInString:str range:range];
					}
					if (m) {
						NSRange r = [m rangeOfSubstringAtIndex:1];
						if (r.location != NSNotFound)
							[self reportConnectionStatus:[str substringWithRange:r]];
						r = [m rangeOfMatchedString];
						range.location = NSMaxRange(r);
						range.length = [str length] - range.location;
					} else
						break;
				}
			}
		}
		break;
	case NSStreamEventHasSpaceAvailable:
		break;
	case NSStreamEventErrorOccurred:
		INFO(@"error on stream %@: %@", stream, [stream streamError]);
		status = [NSString stringWithFormat:@"Lost connection to %@", [self title]];
		[self reportConnectionStatus:status];
		[self abort];
		break;
	case NSStreamEventEndEncountered:
		DEBUG(@"EOF on stream %@", stream);
		status = [NSString stringWithFormat:@"Lost connection to %@", [self title]];
		[self reportConnectionStatus:status];
		INFO(@"%@", status);
		[self abort];
		break;
	}
}

- (void)dequeueRequest:(uint32_t)requestId
{
	NSNumber *key = [NSNumber numberWithUnsignedInt:requestId];
	DEBUG(@"dequeueing request %@", key);
	[requests removeObjectForKey:key];
}

- (SFTPRequest *)addRequest:(uint8_t)requestType format:(const char *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSMutableData *data = fmt ? [NSMutableData data] : nil;
	const char *p;
	for (p = fmt; p && *p; p++) {
		const void *string;
		uint32_t len, tmp;
		NSString *s;
		NSData *d;
		uint32_t u;
		uint64_t q;
		NSDictionary *a;

		DEBUG(@"serializing parameter %c", *p);

		switch (*p) {
		case 's': /* string */
			s = va_arg(ap, NSString *);
			string = [s UTF8String];
			len = (uint32_t)strlen(string); /* XXX: doesn't allow null bytes */
			tmp = CFSwapInt32HostToBig(len);
			[data appendBytes:&tmp length:sizeof(tmp)];
			[data appendBytes:string length:len];
			break;
		case 'd': /* data blob */
			d = va_arg(ap, NSData *);
			string = [d bytes];
			len = (uint32_t)[d length];
			tmp = CFSwapInt32HostToBig(len);
			[data appendBytes:&tmp length:sizeof(tmp)];
			[data appendBytes:string length:len];
			break;
		case 'u': /* uint32_t */
			u = va_arg(ap, uint32_t);
			u = CFSwapInt32HostToBig(u);
			[data appendBytes:&u length:sizeof(u)];
			break;
		case 'q': /* uint64_t */
			q = va_arg(ap, uint64_t);
			q = CFSwapInt64HostToBig(q);
			[data appendBytes:&q length:sizeof(q)];
			break;
		case 'a': /* attributes dictionary */
			a = va_arg(ap, NSDictionary *);
			/* Serialize attributes. */
			// XXX: assume empty attributes for now
			tmp = 0;
			[data appendBytes:&tmp length:sizeof(tmp)];
#if 0
			buffer_put_int(b, a->flags);
			if (a->flags & SSH2_FILEXFER_ATTR_SIZE)
				buffer_put_int64(b, a->size);
			if (a->flags & SSH2_FILEXFER_ATTR_UIDGID) {
				buffer_put_int(b, a->uid);
				buffer_put_int(b, a->gid);
			}
			if (a->flags & SSH2_FILEXFER_ATTR_PERMISSIONS)
				buffer_put_int(b, a->perm);
			if (a->flags & SSH2_FILEXFER_ATTR_ACMODTIME) {
				buffer_put_int(b, a->atime);
				buffer_put_int(b, a->mtime);
			}
#endif
			break;
		default:
			INFO(@"internal error, got parameter %c", *p);
			[self close];
			va_end(ap);
			return nil;
		}
	}
	va_end(ap);

	uint32_t requestId;
	if (requestType == SSH2_FXP_INIT)
		requestId = SSH2_FILEXFER_VERSION;
	else
		requestId = ++nextRequestId;
	DEBUG(@"queueing request %s with id %u and %lu bytes payload",
	    req2txt(requestType), requestId, [data length]);

	struct head {
		uint32_t len;
		uint8_t type;
		uint32_t reqid;
	} __attribute__ ((__packed__));

	struct head head;
	head.len = htonl([data length] + 5);
	head.type = requestType;
	head.reqid = htonl(requestId);
	NSData *headData = [NSData dataWithBytes:&head length:sizeof(head)];
	[sshPipe writeData:headData];
	[sshPipe writeData:data];

	SFTPRequest *req = [SFTPRequest requestWithId:requestId
					       ofType:requestType
					 onConnection:self];
	if (requestType == SSH2_FXP_INIT)
		initRequest = req;
	else
		[requests setObject:req
			     forKey:[NSNumber numberWithUnsignedInt:requestId]];
	return req;
}

- (SFTPRequest *)realpath:(NSString *)path
	       onResponse:(void (^)(NSString *, NSDictionary *, NSError *))responseCallback
{
	void (^originalCallback)(NSString *, NSDictionary *, NSError *) = [responseCallback copy];
	SFTPRequest *req = [self addRequest:SSH2_FXP_REALPATH format:"s", path];
	req.onResponse = ^(SFTPMessage *msg) {
		uint32_t count;
		NSError *error;

		if (![msg expectType:SSH2_FXP_NAME error:&error]) {
			originalCallback(nil, nil, error);
			[self close];
		} else if (![msg getUnsigned:&count]) {
			originalCallback(nil, nil, [ViError errorWithFormat:@"SFTP protocol error"]);
			[self close];
		} else if (count != 1) {
			originalCallback(nil, nil, [ViError errorWithFormat:@"Got multiple names (%d) from SSH_FXP_REALPATH", count]);
		} else {
			NSString *filename;
			NSDictionary *attributes;

			if (![msg getString:&filename] || ![msg getString:NULL] || ![msg getAttributes:&attributes]) {
				originalCallback(nil, nil, [ViError errorWithFormat:@"SFTP protocol error"]);
				[self close];
			} else {
				DEBUG(@"SSH_FXP_REALPATH %@ -> %@", path, filename);
				DEBUG(@"attributes = %@", attributes);
				originalCallback(filename, attributes, nil);
			}
		}
	};
	return req;
}

- (SFTPRequest *)onConnect:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];
	SFTPRequest *req = [self addRequest:SSH2_FXP_INIT format:NULL];
	req.onCancel = ^(SFTPRequest *req) {
		originalCallback([ViError operationCancelled]);
		[self abort];
	};
	req.onResponse = ^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectType:SSH2_FXP_VERSION error:&error]) {
			originalCallback(error);
			[self close];
			return;
		}

		remoteVersion = msg.requestId;
		DEBUG(@"Remote version: %d", remoteVersion);

		/* Check for extensions */
		while ([msg left] > 0) {
			NSString *name, *value;

			if (![msg getStringNoCopy:&name] || ![msg getStringNoCopy:&value])
				break;

			BOOL known = NO;
			if ([name isEqualToString:@"posix-rename@openssh.com"] &&
			    [value isEqualToString:@"1"]) {
				exts |= SFTP_EXT_POSIX_RENAME;
				known = YES;
			} else if ([name isEqualToString:@"statvfs@openssh.com"] &&
				   [value isEqualToString:@"2"]) {
				exts |= SFTP_EXT_STATVFS;
				known = YES;
			} else if ([name isEqualToString:@"fstatvfs@openssh.com"] &&
				   [value isEqualToString:@"2"]) {
				exts |= SFTP_EXT_FSTATVFS;
				known = YES;
			}

			if (known)
				DEBUG(@"Server supports extension \"%@\" revision %@", name, value);
			else
				DEBUG(@"Unrecognised server extension \"%@\"", name);
		}

		/* Some filexfer v.0 servers don't support large packets. */
		transfer_buflen = 32768;
		if (remoteVersion == 0)
			transfer_buflen = MIN(transfer_buflen, 20480);

		req.subRequest = [self realpath:@"." onResponse:^(NSString *filename, NSDictionary *attributes, NSError *error) {
			req.subRequest = nil;
			if (!error) {
				DEBUG(@"resolved home directory to %@", filename);
				home = filename;
			}
			originalCallback(error);
		}];
	};

	return req;
}

- (BOOL)hasPosixRename
{
	return ((exts & SFTP_EXT_POSIX_RENAME) == SFTP_EXT_POSIX_RENAME);
}

- (SFTPConnection *)initWithURL:(NSURL *)url
			  error:(NSError **)outError
{
	self = [super init];
	if (self) {
		ssh_task = [[NSTask alloc] init];
		[ssh_task setLaunchPath:@"/usr/bin/ssh"];

		NSMutableArray *arguments = [NSMutableArray array];
		[arguments addObject:@"-oForwardX11 no"];
		[arguments addObject:@"-oForwardAgent no"];
		[arguments addObject:@"-oPermitLocalCommand no"];
		[arguments addObject:@"-oClearAllForwardings yes"];
		[arguments addObject:@"-oConnectTimeout 10"];
		if ([url port])
			[arguments addObject:[NSString stringWithFormat:@"-p %@", [url port]]];
		[arguments addObject:@"-vvv"];
		[arguments addObject:@"-s"];
		if ([[url user] length] > 0)
			[arguments addObject:[NSString stringWithFormat:@"%@@%@", [url user], [url host]]];
		else
			[arguments addObject:[url host]];
		[arguments addObject:@"sftp"];

		DEBUG(@"ssh arguments: %@", arguments);
		[ssh_task setArguments:arguments];

		ssh_input = [NSPipe pipe];
		ssh_output = [NSPipe pipe];
		ssh_error = [NSPipe pipe];

		[ssh_task setStandardInput:ssh_input];
		[ssh_task setStandardOutput:ssh_output];
		[ssh_task setStandardError:ssh_error];

		remoteVersion = -1;

		@try {
			[ssh_task launch];
		}
		@catch (NSException *exception) {
			if (outError)
				*outError = [ViError errorWithObject:exception];
			[self close];
			return nil;
		}

		inbuf = [NSMutableData data];
		errbuf = [NSMutableData data];

		int err_fd = [[ssh_error fileHandleForReading] fileDescriptor];
		errStream = [[ViBufferedStream alloc] initWithReadDescriptor:err_fd
							     writeDescriptor:-1
								    priority:0];
		[errStream setDelegate:self];
		[errStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[errStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSModalPanelRunLoopMode];

		sshPipe = [[ViBufferedStream alloc] initWithTask:ssh_task];
		[sshPipe setDelegate:self];
		[sshPipe scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[sshPipe scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSModalPanelRunLoopMode];

		host = [url host];
		user = [url user];
		port = [url port];

		requests = [NSMutableDictionary dictionary];
	}
	return self;
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	// BOOL hasTrailingSlash = [[aURL absoluteString] hasPrefix:@"/"];
	NSString *path = [aURL relativePath];
	if ([path length] == 0)
		path = home;
	else if ([path hasPrefix:@"~"])
		path = [home stringByAppendingPathComponent:[path substringFromIndex:1]];
	else if ([path hasPrefix:@"/~"])
		path = [home stringByAppendingPathComponent:[path substringFromIndex:2]];
	else
		return [aURL absoluteURL];
	return [[NSURL URLWithString:path relativeToURL:aURL] absoluteURL];
}

- (SFTPRequest *)attributesOfItemAtURL:(NSURL *)url
			    onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback
{
	DEBUG(@"url = [%@]", url);
	url = [self normalizeURL:url];

	void (^originalCallback)(NSURL *, NSDictionary *, NSError *) = [responseCallback copy];
	SFTPRequest *req = [self addRequest:remoteVersion == 0 ? SSH2_FXP_STAT_VERSION_0 : SSH2_FXP_LSTAT format:"s", [url path]];
	req.onResponse = ^(SFTPMessage *msg) {
		NSDictionary *attributes;
		NSError *error;
		if (![msg expectType:SSH2_FXP_ATTRS error:&error])
			originalCallback(nil, nil, error);
		else if (![msg getAttributes:&attributes])
			originalCallback(nil, nil, [ViError errorWithFormat:@"SFTP protocol error"]);
		else {
			DEBUG(@"got attributes %@", attributes);
			originalCallback(url, attributes, nil);
		}
	};
	req.onCancel = ^(SFTPRequest *req) { originalCallback(nil, nil, [ViError operationCancelled]); };

	return req;
}

- (SFTPRequest *)fileExistsAtURL:(NSURL *)url
		      onResponse:(void (^)(NSURL *, BOOL, NSError *))responseCallback
{
	void (^originalCallback)(NSURL *, BOOL, NSError *) = [responseCallback copy];

	return [self attributesOfItemAtURL:url onResponse:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (error) {
			if ([error code] == SSH2_FX_NO_SUCH_FILE)
				error = nil;
			originalCallback(nil, NO, error);
			return;
		}

		/*
		 * XXX: filePosixPermissions truncates its value to 16 bits, loosing any device flags,
		 *      so S_ISDIR(perms) can't be used anymore.
		 */
		uint32_t perms = (uint32_t)[attributes filePosixPermissions];
		if (perms == 0) {
			/* Attributes didn't include permissions, probably because we couldn't read them. */
			originalCallback(nil, NO, [ViError errorWithCode:SSH2_FX_PERMISSION_DENIED
								 format:@"Permission denied"]);
		} else {
			DEBUG(@"got permissions %06o", perms);
			originalCallback(normalizedURL, [[attributes fileType] isEqualToString:NSFileTypeDirectory], nil);
		}
	}];
}

- (SFTPRequest *)closeHandle:(NSData *)handle
		  onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];

	SFTPRequest *req = [self addRequest:SSH2_FXP_CLOSE format:"d", handle];
	req.onResponse = ^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectStatus:SSH2_FX_OK error:&error])
			originalCallback(error);
		else
			originalCallback(nil);
	};
	req.onCancel = ^(SFTPRequest *req) { originalCallback([ViError operationCancelled]); };

	return req;
}

- (SFTPRequest *)contentsOfDirectoryAtURL:(NSURL *)aURL
				onResponse:(void (^)(NSArray *, NSError *))responseCallback
{
	NSURL *url = [self normalizeURL:aURL];

	void (^originalCallback)(NSArray *, NSError *) = [responseCallback copy];

	SFTPRequest *openRequest = [self addRequest:SSH2_FXP_OPENDIR format:"s", [url path]];
	openRequest.onCancel = ^(SFTPRequest *req) { originalCallback(nil, [ViError operationCancelled]); };
	openRequest.onResponse = ^(SFTPMessage *msg) {
		NSData *handle;
		NSError *error;
		if (![msg expectType:SSH2_FXP_HANDLE error:&error]) {
			originalCallback(nil, error);
			return;
		} else if (![msg getBlob:&handle]) {
			originalCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
			[self close];
			return;
		}

		DEBUG(@"got handle [%@]", handle);
		NSMutableArray *entries = [NSMutableArray array];

		void (^cancelfun)(SFTPRequest *);
		cancelfun = ^(SFTPRequest *req) {
			DEBUG(@"%@ cancelled, closing handle %@", req, handle);
			[self closeHandle:handle
			       onResponse:^(NSError *error) {
				if (error)
					INFO(@"failed to close file after cancel: %@",
					    [error localizedDescription]);
			}];
		};
		cancelfun = [cancelfun copy];

		/* Response callback that repeatedly calls SSH2_FXP_READDIR. */
		__block void (^readfun)(SFTPMessage *);
		readfun = ^(SFTPMessage *msg) {
			NSError *error;
			uint32_t count;
			if (msg.type == SSH2_FXP_STATUS) {
				if (![msg expectStatus:SSH2_FX_EOF error:&error]) {
					openRequest.subRequest = nil;
					originalCallback(nil, error);
				} else {
					openRequest.subRequest = [self closeHandle:handle
									onResponse:^(NSError *error) {
						openRequest.subRequest = nil;
						if (error)
							originalCallback(nil, error);
						else
							originalCallback(entries, nil);
					}];
				}
				return;
			} else if (msg.type != SSH2_FXP_NAME || ![msg getUnsigned:&count]) {
				openRequest.subRequest = nil;
				originalCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
				[self close];
				return;
			}

			for (uint32_t i = 0; i < count; i++) {
				NSString *filename;
				NSDictionary *attributes;
				if (![msg getString:&filename] ||
				    ![msg getString:NULL] || /* ignore longname */
				    ![msg getAttributes:&attributes]) {
					openRequest.subRequest = nil;
					originalCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
					[self close];
					return;
				}
				DEBUG(@"got file %@, attributes %@", filename, attributes);

				if ([filename rangeOfString:@"/"].location != NSNotFound)
					INFO(@"Ignoring suspect path \"%@\" during readdir of \"%@\"", filename, url);
				else
					[entries addObject:[NSArray arrayWithObjects:filename, attributes, nil]];
			}

			/* Request another batch of names. */
			SFTPRequest *req = [self addRequest:SSH2_FXP_READDIR format:"d", handle];
			req.onResponse = readfun;
			req.onCancel = cancelfun;
			openRequest.subRequest = req;
		};
		readfun = [readfun copy];

		/* Request a batch of names. */
		SFTPRequest *req = [self addRequest:SSH2_FXP_READDIR format:"d", handle];
		req.onResponse = readfun;
		req.onCancel = cancelfun;
		openRequest.subRequest = req;
	};

	return openRequest;
}

- (SFTPRequest *)createDirectory:(NSString *)path
		      onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];
	SFTPRequest *req = [self addRequest:SSH2_FXP_MKDIR format:"pa", path, [NSDictionary dictionary]];
	req.onResponse = ^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectStatus:SSH2_FX_OK error:&error])
			originalCallback(error);
		else
			originalCallback(nil);
	};
	req.onCancel = ^(SFTPRequest *req) { originalCallback([ViError operationCancelled]); };
	return req;
}

- (void)close
{
	DEBUG(@"Closing connection %@", sshPipe);
	[sshPipe close];
	sshPipe = nil;
	[ssh_task terminate];
	ssh_task = nil;
	ssh_input = ssh_output = ssh_error = nil;
	[errStream close];
	errStream = nil;
}

- (void)abort
{
	[self close];
	DEBUG(@"cancelling outstanding requests: %@", requests);
	for (SFTPRequest *req in [requests allValues])
		[req cancel];
	[requests removeAllObjects];
}

- (BOOL)closed
{
	return sshPipe == nil;
}

- (BOOL)connected
{
	return ![self closed] && remoteVersion != -1;
}

- (NSString *)title
{
	return [NSString stringWithFormat:@"sftp://%@%s%@%s%@",
	    user ? user : @"", user ? "@" : "", host, port ? ":" : "", port ? port : @""];
}

- (SFTPRequest *)openFile:(NSString *)path
	       forWriting:(BOOL)isWrite
	       onResponse:(void (^)(NSData *handle, NSError *error))responseCallback
{
	uint32_t mode;
	if (isWrite)
		mode = SSH2_FXF_WRITE|SSH2_FXF_CREAT|SSH2_FXF_EXCL;
	else
		mode = SSH2_FXF_READ;

	void (^originalCallback)(NSData *, NSError *) = [responseCallback copy];

	SFTPRequest *req = [self addRequest:SSH2_FXP_OPEN format:"sua", path, mode, [NSDictionary dictionary]];
	req.onResponse = ^(SFTPMessage *msg) {
		NSError *error;
		NSData *handle;
		if (![msg expectType:SSH2_FXP_HANDLE error:&error]) {
			originalCallback(nil, error);
			return;
		} else if (![msg getBlob:&handle]) {
			originalCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
			[self close];
			return;
		}

		DEBUG(@"opened file %@ on handle %@", path, handle);
		originalCallback(handle, nil);
	};
	req.onCancel = ^(SFTPRequest *req) { originalCallback(nil, [ViError operationCancelled]); };

	return req;
}

- (SFTPRequest *)dataWithContentsOfURL:(NSURL *)url
				onData:(void (^)(NSData *))dataCallback
			    onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback
{
	void (^originalCallback)(NSURL *, NSDictionary *, NSError *) = [responseCallback copy];
	__block SFTPRequest *statRequest = nil;

	void (^fun)(NSURL *, NSDictionary *, NSError *) = ^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (error) {
			originalCallback(url, nil, error);
			return;
		}

		if (![[attributes fileType] isEqualToString:NSFileTypeRegular]) {
			originalCallback(normalizedURL, attributes,
			    [ViError errorWithFormat:@"%@ is not a regular file", [normalizedURL path]]);
			return;
		}

		NSUInteger fileSize = [attributes fileSize]; /* may be zero */
		statRequest.progress = 0.0;

		statRequest.subRequest = [self openFile:[normalizedURL path] forWriting:NO onResponse:^(NSData *handle, NSError *error) {
			__block uint64_t offset = 0;
			__block uint32_t len = transfer_buflen;

			void (^cancelfun)(SFTPRequest *);
			cancelfun = ^(SFTPRequest *req) {
				DEBUG(@"%@ cancelled, closing handle %@", req, handle);
				originalCallback(normalizedURL, attributes, [ViError operationCancelled]);
				[self closeHandle:handle
				       onResponse:^(NSError *error) {
					if (error)
						INFO(@"failed to close file after cancel: %@",
						    [error localizedDescription]);
				}];
			};
			cancelfun = [cancelfun copy];

			__block void (^readfun)(SFTPMessage *);
			readfun = ^(SFTPMessage *msg) {
				NSError *error;
				if (msg.type == SSH2_FXP_STATUS) {
					if (![msg expectStatus:SSH2_FX_EOF error:&error]) {
						originalCallback(normalizedURL, attributes, error);
						[self closeHandle:handle
						       onResponse:^(NSError *error) {
							if (error)
								INFO(@"failed to close file after read error: %@",
								    [error localizedDescription]);
						}];
						statRequest.subRequest = nil;
						return;
					}
					DEBUG(@"%s", "got EOF, closing handle");
					statRequest.subRequest = [self closeHandle:handle
									onResponse:^(NSError *error) {
						statRequest.subRequest = nil;
						originalCallback(normalizedURL, attributes, error);
					}];
					/*
					 * Done downloading file.
					 */
					 return;
				} else if (![msg expectType:SSH2_FXP_DATA error:&error]) {
					originalCallback(normalizedURL, attributes, error);
					[self closeHandle:handle
					       onResponse:^(NSError *error) {
						if (error)
							INFO(@"failed to close file after protocol error: %@",
							    [error localizedDescription]);
					}];
					statRequest.subRequest = nil;
					return;
				}

				NSData *data;
				if (![msg getBlob:&data]) {
					originalCallback(normalizedURL, attributes, [ViError errorWithFormat:@"SFTP protocol error"]);
					[self close];
					statRequest.subRequest = nil;
					return;
				}

				DEBUG(@"got %lu bytes of data, requested %u", [data length], len);
				if (dataCallback)
					dataCallback(data);
				offset += [data length];
				if (fileSize > 0)
					statRequest.progress = (CGFloat)offset / (CGFloat)fileSize;
				else
					statRequest.progress = -1.0; /* unknown/indefinite progress */

				/* Data callback may have cancelled us. */
				if (statRequest.cancelled)
					return;

				if ([data length] < len)
					len = (uint32_t)[data length];

				/* Dispatch next read request. */
				for (int i = 0; i < 1/*max_req*/; i++) {
					DEBUG(@"requesting %u bytes at offset %lu", len, offset);
					SFTPRequest *req = [self addRequest:SSH2_FXP_READ format:"dqu", handle, offset, len];
					req.onResponse = readfun;
					req.onCancel = cancelfun;
					statRequest.subRequest = req;
				}
			};
			readfun = [readfun copy];

			/* Dispatch first read request. */
			DEBUG(@"requesting %u bytes at offset %lu", len, offset);
			SFTPRequest *req = [self addRequest:SSH2_FXP_READ format:"dqu", handle, offset, len];
			req.onResponse = readfun;
			req.onCancel = cancelfun;
			statRequest.subRequest = req;
		}];
	};

	statRequest = [self attributesOfItemAtURL:url onResponse:fun];
	return statRequest;
}

- (NSString *)randomFileAtDirectory:(NSString *)aDirectory
{
	char tmp[37];
	uuid_t uuid;
	uuid_generate(uuid);
	uuid_unparse(uuid, tmp);

	return [aDirectory stringByAppendingPathComponent:[NSString stringWithUTF8String:tmp]];
}

- (SFTPRequest *)uploadData:(NSData *)data
		     toFile:(NSString *)path
		 onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];
	__block SFTPRequest *openRequest = nil;

	void (^fun)(NSData *, NSError *) = ^(NSData *handle, NSError *error) {
		if (error) {
			originalCallback(error);
			return;
		}

		void (^cancelfun)(SFTPRequest *);
		cancelfun = ^(SFTPRequest *req) {
			DEBUG(@"%@ cancelled, closing handle %@", req, handle);
			responseCallback([ViError operationCancelled]);
			[self closeHandle:handle
			       onResponse:^(NSError *error) {
				if (error)
					INFO(@"failed to close file after cancel: %@",
					    [error localizedDescription]);
			}];
		};
		cancelfun = [cancelfun copy];

		__block uint64_t offset = 0;

		__block void (^writefun)(SFTPMessage *);
		writefun = ^(SFTPMessage *msg) {
			NSError *error;
			if (![msg expectStatus:SSH2_FX_OK error:&error]) {
				originalCallback(error);
				[self closeHandle:handle
				       onResponse:^(NSError *error) {
					if (error)
						INFO(@"failed to close file after write error: %@",
						    [error localizedDescription]);
				}];
				openRequest.subRequest = nil;
				return;
			}

			if (offset == [data length]) {
				DEBUG(@"finished uploading %lu bytes, closing file", [data length]);
				openRequest.subRequest = [self closeHandle:handle
								onResponse:^(NSError *error) {
					openRequest.subRequest = nil;
					originalCallback(error);
				}];
				return;
			}

			/* Dispatch next read request. */
			uint32_t len = transfer_buflen;
			if (offset + len > [data length])
				len = (uint32_t)([data length] - offset);
			NSData *chunk = [NSData dataWithBytesNoCopy:(void *)[data bytes] + offset length:len freeWhenDone:NO];
			DEBUG(@"writing %u bytes at offset %lu", len, offset);
			SFTPRequest *req = [self addRequest:SSH2_FXP_WRITE format:"dqd", handle, offset, chunk];
			offset += len;
			req.onResponse = writefun;
			req.onCancel = cancelfun;
			openRequest.subRequest = req;
		};
		writefun = [writefun copy];

		/* Dispatch first read request. */
		uint32_t len = transfer_buflen;
		if (offset + len > [data length])
			len = (uint32_t)([data length] - offset);
		NSData *chunk = [NSData dataWithBytesNoCopy:(void *)[data bytes] + offset length:len freeWhenDone:NO];
		DEBUG(@"writing %u bytes at offset %lu", len, offset);
		SFTPRequest *req = [self addRequest:SSH2_FXP_WRITE format:"dqd", handle, offset, chunk];
		offset += len;
		req.onResponse = writefun;
		req.onCancel = cancelfun;
		openRequest.subRequest = req;
	};

	openRequest = [self openFile:path forWriting:YES onResponse:fun];

	return openRequest;
}

- (SFTPRequest *)removeItemAtPath:(NSString *)path
		       onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];
	SFTPRequest *req = [self addRequest:SSH2_FXP_REMOVE format:"s", path];
	req.onResponse = ^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectStatus:SSH2_FX_OK error:&error])
			originalCallback(error);
		else
			originalCallback(nil);
	};
	req.onCancel = ^(SFTPRequest *req) { originalCallback([ViError operationCancelled]); };
	return req;
}

- (SFTPRequest *)removeItemsAtURLs:(NSArray *)urls
		       onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];
	NSMutableArray *mutableURLs = [urls mutableCopy];

	/* Dispatch all requests at once. */
	SFTPRequest *req = nil;
	for (NSURL *url in mutableURLs) {
		req = [self removeItemAtPath:[url path] onResponse:^(NSError *error) {
			[mutableURLs removeObject:url];
			if (error)
				originalCallback(error);
			if ([mutableURLs count] == 0)
				originalCallback(nil);
		}];
	}

	return req; /* XXX: only returns the last request. */
}

- (SFTPRequest *)renameItemAtPath:(NSString *)oldPath
			   toPath:(NSString *)newPath
		       onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];
	SFTPRequest *req = [self addRequest:SSH2_FXP_RENAME format:"ss", oldPath, newPath];
	req.onResponse = ^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectStatus:SSH2_FX_OK error:&error])
			originalCallback(error);
		else
			originalCallback(nil);
	};
	req.onCancel = ^(SFTPRequest *req) { originalCallback([ViError operationCancelled]); };

	return req;
}

- (SFTPRequest *)atomicallyRenameItemAtPath:(NSString *)oldPath
				     toPath:(NSString *)newPath
				 onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [responseCallback copy];
	__block SFTPRequest *renameRequest = nil;
	if ([self hasPosixRename]) {
		/*
		 * With POSIX rename support, we're guaranteed to be able to atomically replace the file.
		 */
		renameRequest = [self addRequest:SSH2_FXP_EXTENDED format:"sss", @"posix-rename@openssh.com", oldPath, newPath];
		renameRequest.onResponse = ^(SFTPMessage *msg) {
			NSError *error;
			if (![msg expectStatus:SSH2_FX_OK error:&error])
				originalCallback(error);
			else
				originalCallback(nil);
		};
		renameRequest.onCancel = ^(SFTPRequest *req) { originalCallback([ViError operationCancelled]); };
	} else {
		/*
		 * Without POSIX rename support, first move away the existing file, rename our temporary file
		 * to correct name, and finally delete the original file.
		 */
		NSString *dir = [oldPath stringByDeletingLastPathComponent];
		NSString *randomFilename = [self randomFileAtDirectory:dir];

		void (^fun)(NSError *error) = ^(NSError *error) {
			BOOL newPathExists = YES;
			if (error) {
				if ([error code] == SSH2_FX_NO_SUCH_FILE)
					newPathExists = NO;
				else {
					originalCallback(error);
					return;
				}
			}

			renameRequest.subRequest = [self renameItemAtPath:oldPath toPath:newPath onResponse:^(NSError *error) {
				if (!newPathExists) {
					/* If the new path didn't exist, we're done. */
					renameRequest.subRequest = nil;
					originalCallback(error);
					return;
				}

				/* Otherwise, we must clean up the temporary random filename. */
				renameRequest.subRequest = [self removeItemAtPath:randomFilename onResponse:^(NSError *error) {
					renameRequest.subRequest = nil;
					originalCallback(error);
				}];
			}];
		};

		renameRequest = [self renameItemAtPath:newPath toPath:randomFilename onResponse:fun];
	}

	return renameRequest;
}

- (SFTPRequest *)writeDataSafely:(NSData *)data
			   toURL:(NSURL *)aURL
		      onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback
{
	NSURL *url = [self normalizeURL:aURL];

	void (^originalCallback)(NSURL *, NSDictionary *, NSError *) = [responseCallback copy];
	__block SFTPRequest *uploadRequest = nil;

	void (^fun)(NSError *) = ^(NSError *error) {
		if (error && [error code] == SSH2_FX_FAILURE) {
			/* File already exists. Probably. */
			/* Upload to a random file, then rename it to our destination filename. */
			NSString *randomFilename = [self randomFileAtDirectory:[[url path] stringByDeletingLastPathComponent]];
			uploadRequest.subRequest = [self uploadData:data
							   toFile:randomFilename
						       onResponse:^(NSError *error) {
				if (error) {
					uploadRequest.subRequest = nil;
					originalCallback(url, nil, error);
					return;
				}
				uploadRequest.subRequest = [self atomicallyRenameItemAtPath:randomFilename
										     toPath:[url path]
										 onResponse:^(NSError *error) {
					uploadRequest.subRequest = [self attributesOfItemAtURL:url
										    onResponse:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
						uploadRequest.subRequest = nil;
						originalCallback(normalizedURL, attributes, error);
					}];
				}];
			}];
		} else {
			/* It was a new file, upload successful. Or other error. */
			if (error) {
				uploadRequest.subRequest = nil;
				originalCallback(url, nil, error);
				return;
			}

			uploadRequest.subRequest = [self attributesOfItemAtURL:url
								    onResponse:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
				uploadRequest.subRequest = nil;
				originalCallback(normalizedURL, attributes, error);
			}];
		}
	};

	uploadRequest = [self uploadData:data toFile:[url path] onResponse:fun];

	return uploadRequest;
}

- (NSString *)stderr
{
	NSString *str;
	char *buf;

	str = [[NSString alloc] initWithData:errbuf encoding:NSUTF8StringEncoding];
	if (str)
		return str;

	/* Not valid UTF-8, convert to ASCII */

	if ((buf = malloc(4 * [errbuf length] + 1)) == NULL) {
		return @"";
	}

	strvisx(buf, [errbuf bytes], [errbuf length], VIS_NOSLASH);
	str = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
	free(buf);
	return str;
}

@end

