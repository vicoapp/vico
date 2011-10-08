#import "SFTPConnection.h"
#import "ViError.h"
#import "ViRegexp.h"
#import "ViFile.h"
#import "NSURL-additions.h"

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

@synthesize onResponse = _responseCallback;
@synthesize onCancel = _cancelCallback;
@synthesize cancelled = _cancelled;
@synthesize requestId = _requestId;
@synthesize subRequest = _subRequest;
@synthesize progress = _progress;
@synthesize delegate = _delegate;
@synthesize waitRequest = _waitRequest;

+ (SFTPRequest *)requestWithId:(uint32_t)reqId
			ofType:(uint32_t)type
		  onConnection:(SFTPConnection *)aConnection
{
	return [[[SFTPRequest alloc] initWithId:reqId
					 ofType:type
				   onConnection:aConnection] autorelease];
}

- (SFTPRequest *)initWithId:(uint32_t)reqId
		     ofType:(uint32_t)type
	       onConnection:(SFTPConnection *)aConnection
{
	if ((self = [super init]) != nil) {
		_requestId = reqId;
		_requestType = type;
		_connection = [aConnection retain];
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_connection release];
	[_subRequest release];
	[_waitRequest release];
	[waitWindow release];
	[_responseCallback release];
	[_cancelCallback release];
	[super dealloc];
}

- (void)response:(SFTPMessage *)msg
{
	BOOL gotWaitResponse = NO;
	if (_waitRequest && (_waitRequest == self || _waitRequest.subRequest == self)) {
		gotWaitResponse = YES;
		DEBUG(@"got wait response %@ for %@", msg, _waitRequest);
	}

	if (_responseCallback)
		_responseCallback(msg);
	else
		DEBUG(@"NULL response callback for request id %u", _requestId);
	_finished = YES;

	if (gotWaitResponse) {
		if (_waitRequest.subRequest) {
			_waitRequest.subRequest.waitRequest = _waitRequest;
		} else {
			DEBUG(@"stopping wait request %@", _waitRequest);
			[NSApp abortModal];
		}
	} else
		DEBUG(@"no wait request for request %@", self);
}

- (void)cancel
{
	if (_cancelled) {
		INFO(@"%@ already cancelled", self);
		return;
	}

	DEBUG(@"cancelling request %@", self);
	_cancelled = YES;
	_finished = YES;
	[_connection dequeueRequest:_requestId];

	if (_cancelCallback) {
		DEBUG(@"running cancel callback %p", _cancelCallback);
		_cancelCallback(self);
	}

	/* If this request has subrequests, cancel them too. */
	if (_subRequest) {
		[_subRequest cancel];
		self.subRequest = nil;
	}

	if (waitWindow) {
		DEBUG(@"aborting wait window %@", waitWindow);
		[NSApp abortModal];
	}
}

- (IBAction)cancelTask:(id)sender
{
	DEBUG(@"cancelling wait window %@ with code 2", waitWindow);
	[NSApp stopModalWithCode:2];
}

- (void)waitInWindow:(NSWindow *)window
             message:(NSString *)waitMessage
           limitDate:(NSDate *)limitDate
{
	self.waitRequest = self;

	/* Run and block the UI for 2 seconds. */
	while ([limitDate timeIntervalSinceNow] > 0) {
		if (_cancelled) {
			DEBUG(@"request %@ was cancelled", self);
			return;
		}
		if (_finished) {
			DEBUG(@"request %@ finished, waiting for subRequest %@",
				self, _subRequest);
			[_subRequest waitInWindow:window
					  message:waitMessage
					limitDate:limitDate];
			return;
		}
		DEBUG(@"waiting for request %@ until %@", _waitRequest, limitDate);
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
					 beforeDate:limitDate];
	}

	DEBUG(@"limitdate %@ reached, presenting cancellable sheet", limitDate);

	/* Continue with a sheet with a cancel button. */
	[NSBundle loadNibNamed:@"WaitProgress" owner:self];
	[waitLabel setStringValue:waitMessage];
	[progressIndicator startAnimation:nil];
	[waitWindow setTitle:[NSString stringWithFormat:@"Waiting on %@", _connection.title]];

	NSInteger reason = [NSApp runModalForWindow:waitWindow];

	DEBUG(@"wait window %@ done with reason %li", waitWindow, reason);
	[progressIndicator stopAnimation:nil];
	[waitWindow orderOut:nil];
	waitWindow = nil;

	if (reason == 2)
		[self cancel];

	/* Wait for subrequests. */
	while (_subRequest && !_cancelled) {
		DEBUG(@"waiting for subrequest %@", _subRequest);
		SFTPRequest *req = _subRequest;
		[req waitInWindow:window message:waitMessage limitDate:limitDate];
		if (_subRequest == req) {
			INFO(@"Warning: request %@ didn't reset subRequest after %@", self, req);
			break;
		}
	}

	DEBUG(@"request %@ is finished", self);
}

- (void)waitInWindow:(NSWindow *)window message:(NSString *)waitMessage
{
	NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:2.0];
	[self waitInWindow:window message:waitMessage limitDate:limitDate];
}

- (void)wait
{
	while (!_finished) {
		DEBUG(@"request %@ not finished yet", self);
		[[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
				      beforeDate:[NSDate distantFuture]];
	}

	while (_subRequest && !_cancelled) {
		DEBUG(@"waiting for subrequest %@", _subRequest);
		SFTPRequest *req = _subRequest;
		[req wait];
		if (_subRequest == req) {
			DEBUG(@"Warning: request %@ didn't reset subRequest after %@", self, req);
			break;
		}
	}

	DEBUG(@"request %@ is finished", self);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<SFTPRequest %p: %s, id %u>",
	    self, req2txt(_requestType), _requestId];
}

@end


#pragma mark -


@implementation SFTPMessage

@synthesize type = _type;
@synthesize requestId = _requestId;
@synthesize data = _data;

+ (SFTPMessage *)messageWithData:(NSData *)someData
{
	return [[[SFTPMessage alloc] initWithData:someData] autorelease];
}

- (SFTPMessage *)initWithData:(NSData *)someData
{
	if ((self = [super init]) != nil) {
		_data = [someData retain];
		_ptr = [_data bytes];
		if (![self getByte:&_type] ||
		    ![self getUnsigned:&_requestId]) {
			[self release];
			return nil;
		}
	}
	return self;
}

- (void)dealloc
{
	[_data release];
	[super dealloc];
}

- (NSInteger)left
{
	return [_data length] - (_ptr - [_data bytes]);
}

- (void)reset
{
	_ptr = [_data bytes];
}

- (BOOL)getStringNoCopy:(NSString **)outString
{
	uint32_t len;
	if (![self getUnsigned:&len] || [self left] < len)
		return NO;

	if (outString) {
		NSString *str = [[NSString alloc] initWithBytesNoCopy:(void *)_ptr
							       length:len
							     encoding:NSUTF8StringEncoding
							 freeWhenDone:NO];
		if (str == nil)
			str = [[NSString alloc] initWithBytesNoCopy:(void *)_ptr
							     length:len
							   encoding:NSISOLatin1StringEncoding
						       freeWhenDone:NO];

		*outString = [str autorelease];
	}

	_ptr += len;
	return YES;
}

- (BOOL)getString:(NSString **)outString
{
	uint32_t len;
	if (![self getUnsigned:&len] || [self left] < len)
		return NO;

	if (outString) {
		NSString *str = [[NSString alloc] initWithBytes:(void *)_ptr
							 length:len
						       encoding:NSUTF8StringEncoding];
		if (str == nil)
			str = [[NSString alloc] initWithBytes:(void *)_ptr
						       length:len
						     encoding:NSISOLatin1StringEncoding];

		*outString = [str autorelease];
	}

	_ptr += len;
	return YES;
}

- (BOOL)getBlob:(NSData **)outData
{
	uint32_t len;
	if (![self getUnsigned:&len] || [self left] < len)
		return NO;
	if (outData)
		*outData = [NSData dataWithBytes:_ptr length:len];

	_ptr += len;
	return YES;
}

- (BOOL)getByte:(uint8_t *)ret
{
	if ([self left] == 0)
		return NO;
	*ret = *(uint8_t *)_ptr++;
	return YES;
}

- (BOOL)getUnsigned:(uint32_t *)ret
{
	if ([self left] < sizeof(uint32_t))
		return NO;

	uint32_t tmp;
	bcopy(_ptr, &tmp, sizeof(tmp));
	_ptr += sizeof(tmp);
	*ret = CFSwapInt32BigToHost(tmp);
	return YES;
}

- (BOOL)getInt64:(int64_t *)ret;
{
	if ([self left] < sizeof(uint64_t))
		return NO;

	uint64_t tmp;
	bcopy(_ptr, &tmp, sizeof(tmp));
	_ptr += sizeof(tmp);
	*ret = CFSwapInt64BigToHost(tmp);
	return YES;
}

- (BOOL)expectStatus:(uint32_t)expectedStatus
	       error:(NSError **)outError
{
	uint32_t status = 0;
	NSString *errmsg = nil;
	if (_type == SSH2_FXP_STATUS) {
		if ([self getUnsigned:&status] && status == expectedStatus)
			return YES;
		[self getStringNoCopy:&errmsg];
	}

	DEBUG(@"unexpected status code %u (wanted %u)", status, expectedStatus);

	if (outError) {
		if (status != 0) {
			if (errmsg)
				*outError = [ViError errorWithCode:status
							    format:@"%@", errmsg];
			else
				*outError = [ViError errorWithCode:status
							    format:@"%s", fx2txt(status)];
		} else
			*outError = [ViError message:@"SFTP protocol error"];
	}
	return NO;
}

- (BOOL)expectType:(uint32_t)expectedType
	     error:(NSError **)outError
{
	if (_type == expectedType)
		return YES;

	DEBUG(@"unexpected type %u (wanted %u)", _type, expectedType);
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
		[attributes setObject:[NSNumber numberWithUnsignedLongLong:size]
			       forKey:NSFileSize];
	}

	if (flags & SSH2_FILEXFER_ATTR_UIDGID) {
		if (![self getUnsigned:&uid] || ![self getUnsigned:&gid])
			return NO;
		[attributes setObject:[NSNumber numberWithUnsignedInt:uid]
			       forKey:NSFileOwnerAccountID];
		[attributes setObject:[NSNumber numberWithUnsignedInt:gid]
			       forKey:NSFileGroupOwnerAccountID];
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
		[attributes setObject:[NSDate dateWithTimeIntervalSince1970:atime]
			       forKey:@"ViFileAccessDate"];
		[attributes setObject:[NSDate dateWithTimeIntervalSince1970:mtime]
			       forKey:NSFileModificationDate];
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
	return [NSString stringWithFormat:@"<SFTPMessage %s, id %u>", resp2txt(_type), _requestId];
}

@end


#pragma mark -

@implementation SFTPConnection

/* Max number of concurrent outstanding requests */
#define NUM_REQUESTS 64

@synthesize host = _host;
@synthesize user = _user;
@synthesize home = _home;

- (BOOL)fail:(NSError **)outError with:(NSString *)fmt, ...
{
	if (outError) {
		va_list ap;
		va_start(ap, fmt);
		NSString *msg = [[[NSString alloc] initWithFormat:fmt arguments:ap] autorelease];
		*outError = [ViError errorWithObject:msg];
		va_end(ap);
	}
	[self close];
	return NO;
}

- (void)reportConnectionStatus:(NSString *)status
{
	DEBUG(@"reporting connection status [%@]", status);
	for (SFTPRequest *req in [_requests objectEnumerator])
		if ([req.delegate respondsToSelector:@selector(deferred:status:)])
			[req.delegate deferred:req status:status];
	if ([_initRequest.delegate respondsToSelector:@selector(deferred:status:)])
		[_initRequest.delegate deferred:_initRequest status:status];
}

- (SFTPMessage *)readMessage
{
	NSUInteger len = [_inbuf length];

	if (len == 0)
		return nil;

	if (len <= sizeof(uint32_t)) {
		DEBUG(@"buffer too small: got %lu bytes, need > 4 bytes", len);
		return nil;
	}

	uint32_t msg_len;
	[_inbuf getBytes:&msg_len range:NSMakeRange(0, 4)];
	msg_len = ntohl(msg_len);
	DEBUG(@"message length is %u", msg_len);

	if (msg_len < 5) {
		DEBUG(@"message too small: is %lu bytes, should be >= 5 bytes", msg_len);
		/* Just skip this message and try next. */
		[_inbuf replaceBytesInRange:NSMakeRange(0, msg_len + sizeof(uint32_t))
				  withBytes:NULL
				     length:0];
		return [self readMessage];
	}

	if (len - sizeof(uint32_t) < msg_len) {
		DEBUG(@"buffer too small: got %lu bytes, need %lu bytes",
			len, msg_len + sizeof(uint32_t));
		return nil;
	}

	NSData *data = [_inbuf subdataWithRange:NSMakeRange(sizeof(uint32_t), msg_len)];

	// hexdump([data bytes], msg_len, "raw message bytes:");

	/* Drain the extracted bytes. */
	[_inbuf replaceBytesInRange:NSMakeRange(0, msg_len + sizeof(uint32_t))
			  withBytes:NULL
			     length:0];

	SFTPMessage *msg = [SFTPMessage messageWithData:data];
	return msg;
}

- (void)dispatchMessages
{
	SFTPMessage *msg;
	while ((msg = [self readMessage]) != nil) {
		if (msg.type == SSH2_FXP_VERSION) {
			if (_initRequest == nil)
				INFO(@"%s", "spurious version response");
			else
				[_initRequest response:msg];
			[_initRequest release];
			_initRequest = nil;
		} else {
			NSNumber *req_id = [NSNumber numberWithUnsignedInt:msg.requestId];
			SFTPRequest *request = [_requests objectForKey:req_id];
			if (request == nil) {
				INFO(@"spurious request id %@", req_id);
				INFO(@"current request queue: %@", _requests);
			} else {
				DEBUG(@"got response %@ to request %@", msg, request);
				[request response:msg];
				[_requests removeObjectForKey:req_id];
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
		if (stream == _sshPipe) {
			[_sshPipe getBuffer:&ptr length:&len];
			DEBUG(@"got %lu bytes", len);
			if (len > 0) {
				[_inbuf appendBytes:ptr length:len];
				[self dispatchMessages];
			}
		} else if (stream == _errStream) {
			[_errStream getBuffer:&ptr length:&len];
			DEBUG(@"got %lu bytes", len);
			if (len > 0) {
				[_errbuf appendBytes:ptr length:len];

				NSString *str = [[[NSString alloc] initWithBytesNoCopy:(void *)ptr
										length:len
									      encoding:NSISOLatin1StringEncoding
									  freeWhenDone:NO] autorelease];
				DEBUG(@"read data: [%@]", str);

				NSRange range = NSMakeRange(0, [str length]);
				while (range.length > 0) {
					DEBUG(@"looking for connect messages in range %@", NSStringFromRange(range));
					unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;
					ViRegexp *rx = [ViRegexp regexpWithString:@"^debug1: (Connecting to .*)$"
									  options:rx_options];
					ViRegexpMatch *m = [rx matchInString:str range:range];
					if (m == nil) {
						rx = [ViRegexp regexpWithString:@"^debug1: (connect to address .* port .*: .*)$"
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
	case ViStreamEventWriteEndEncountered:
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
	[_requests removeObjectForKey:key];
}

- (SFTPRequest *)addRequest:(uint8_t)requestType format:(const char *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSMutableData *data = fmt ? [NSMutableData data] : nil;
	const char *p;
	for (p = fmt; p && *p; p++) {
		const void *string;
		uint32_t len, tmp, flags;
		NSString *s;
		NSData *d;
		uint32_t u;
		uint64_t q;
		NSDictionary *a;

		DEBUG(@"serializing parameter %c", *p);

		switch (*p) {
		case 's': /* string */
			s = va_arg(ap, NSString *);
			if (s == NULL) {
				INFO(@"%s", "NULL parameter");
				return nil;
			}
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
			flags = 0;
			if ([a fileGroupOwnerAccountID] && [a fileOwnerAccountID])
				flags |= SSH2_FILEXFER_ATTR_UIDGID;
			if ([a filePosixPermissions] != 0)
				flags |= SSH2_FILEXFER_ATTR_PERMISSIONS;
			if ([a objectForKey:@"ViFileAccessDate"] && [a fileModificationDate])
				flags |= SSH2_FILEXFER_ATTR_ACMODTIME;
			DEBUG(@"encoded attribute flags 0x%04x", flags);
			u = CFSwapInt32HostToBig(flags);
			[data appendBytes:&u length:sizeof(u)];
			if (flags & SSH2_FILEXFER_ATTR_UIDGID) {
				u = [[a fileOwnerAccountID] unsignedIntValue];
				DEBUG(@"encoded uid %u", u);
				u = CFSwapInt32HostToBig(u);
				[data appendBytes:&u length:sizeof(u)];
				u = [[a fileGroupOwnerAccountID] unsignedIntValue];
				DEBUG(@"encoded gid %u", u);
				u = CFSwapInt32HostToBig(u);
				[data appendBytes:&u length:sizeof(u)];
			}
			if (flags & SSH2_FILEXFER_ATTR_PERMISSIONS) {
				u = (uint32_t)[a filePosixPermissions];
				DEBUG(@"encoded posix permissions 0%03o", u);
				u = CFSwapInt32HostToBig(u);
				[data appendBytes:&u length:sizeof(u)];
			}
			if (flags & SSH2_FILEXFER_ATTR_ACMODTIME) {
				NSDate *at = [a objectForKey:@"ViFileAccessDate"];
				NSDate *mt = [a fileModificationDate];
				u = [at timeIntervalSince1970];
				DEBUG(@"encoded atime %u", u);
				u = CFSwapInt32HostToBig(u);
				[data appendBytes:&u length:sizeof(u)];
				u = [mt timeIntervalSince1970];
				DEBUG(@"encoded mtime %u", u);
				u = CFSwapInt32HostToBig(u);
				[data appendBytes:&u length:sizeof(u)];
			}
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
		requestId = ++_nextRequestId;
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
	[_sshPipe writeData:headData];
	[_sshPipe writeData:data];

	SFTPRequest *req = [SFTPRequest requestWithId:requestId
					       ofType:requestType
					 onConnection:self];
	if (requestType == SSH2_FXP_INIT)
		_initRequest = [req retain];
	else
		[_requests setObject:req
			      forKey:[NSNumber numberWithUnsignedInt:requestId]];
	return req;
}

- (SFTPRequest *)realpath:(NSString *)path
	       onResponse:(void (^)(NSString *, NSDictionary *, NSError *))responseCallback
{
	void (^originalCallback)(NSString *, NSDictionary *, NSError *) = [[responseCallback copy] autorelease];
	SFTPRequest *req = [self addRequest:SSH2_FXP_REALPATH format:"s", path];
	req.onResponse = ^(SFTPMessage *msg) {
		uint32_t count;
		NSError *error;

		if (![msg expectType:SSH2_FXP_NAME error:&error]) {
			originalCallback(nil, nil, error);
			[self close];
		} else if (![msg getUnsigned:&count]) {
			originalCallback(nil, nil, [ViError message:@"SFTP protocol error"]);
			[self close];
		} else if (count != 1) {
			originalCallback(nil, nil, [ViError errorWithFormat:@"Got multiple names (%d) from SSH_FXP_REALPATH", count]);
		} else {
			NSString *filename;
			NSDictionary *attributes;

			if (![msg getString:&filename] || ![msg getString:NULL] || ![msg getAttributes:&attributes]) {
				originalCallback(nil, nil, [ViError message:@"SFTP protocol error"]);
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
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
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

		_remoteVersion = msg.requestId;
		DEBUG(@"Remote version: %d", _remoteVersion);

		/* Check for extensions */
		while ([msg left] > 0) {
			NSString *name, *value;

			if (![msg getStringNoCopy:&name] || ![msg getStringNoCopy:&value])
				break;

			BOOL known = NO;
			if ([name isEqualToString:@"posix-rename@openssh.com"] &&
			    [value isEqualToString:@"1"]) {
				_exts |= SFTP_EXT_POSIX_RENAME;
				known = YES;
			} else if ([name isEqualToString:@"statvfs@openssh.com"] &&
				   [value isEqualToString:@"2"]) {
				_exts |= SFTP_EXT_STATVFS;
				known = YES;
			} else if ([name isEqualToString:@"fstatvfs@openssh.com"] &&
				   [value isEqualToString:@"2"]) {
				_exts |= SFTP_EXT_FSTATVFS;
				known = YES;
			}

			if (known)
				DEBUG(@"Server supports extension \"%@\" revision %@", name, value);
			else
				DEBUG(@"Unrecognised server extension \"%@\"", name);
		}

		/* Some filexfer v.0 servers don't support large packets. */
		_transfer_buflen = 32768;
		if (_remoteVersion == 0)
			_transfer_buflen = MIN(_transfer_buflen, 20480);

		req.subRequest = [self realpath:@"." onResponse:^(NSString *filename, NSDictionary *attributes, NSError *error) {
			req.subRequest = nil;
			if (!error) {
				DEBUG(@"resolved home directory to %@", filename);
				self.home = filename;
			}
			originalCallback(error);
		}];
	};

	return req;
}

- (BOOL)hasPosixRename
{
	return ((_exts & SFTP_EXT_POSIX_RENAME) == SFTP_EXT_POSIX_RENAME);
}

- (SFTPConnection *)initWithURL:(NSURL *)url
			  error:(NSError **)outError
{
	if ((self = [super init]) != nil) {
		_ssh_task = [[NSTask alloc] init];
		[_ssh_task setLaunchPath:@"/usr/bin/ssh"];

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
		[_ssh_task setArguments:arguments];

		NSPipe *ssh_input = [NSPipe pipe];
		NSPipe *ssh_output = [NSPipe pipe];
		NSPipe *ssh_error = [NSPipe pipe];

		[_ssh_task setStandardInput:ssh_input];
		[_ssh_task setStandardOutput:ssh_output];
		[_ssh_task setStandardError:ssh_error];

		_remoteVersion = -1;

		@try {
			[_ssh_task launch];
		}
		@catch (NSException *exception) {
			if (outError)
				*outError = [ViError errorWithObject:exception];
			[self close];
			return nil;
		}

		_inbuf = [[NSMutableData alloc] init];
		_errbuf = [[NSMutableData alloc] init];

		int err_fd = [[ssh_error fileHandleForReading] fileDescriptor];
		_errStream = [[ViBufferedStream alloc] initWithReadDescriptor:err_fd
							      writeDescriptor:-1
								     priority:0];
		[_errStream setDelegate:self];
		[_errStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[_errStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSModalPanelRunLoopMode];

		_sshPipe = [[ViBufferedStream alloc] initWithTask:_ssh_task];
		[_sshPipe setDelegate:self];
		[_sshPipe scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		[_sshPipe scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSModalPanelRunLoopMode];

		_host = [[url host] retain];
		_user = [[url user] retain];
		_port = [[url port] retain];

		_requests = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[self close];
	[_inbuf release];
	[_errbuf release];
	[_initRequest release];
	[_requests release];
	[_host release];
	[_user release];
	[_port release];
	[_home release];
	[super dealloc];
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	// BOOL hasTrailingSlash = [[aURL absoluteString] hasPrefix:@"/"];
	NSString *path = [aURL relativePath];
	if ([path length] == 0)
		path = _home;
	else if ([path hasPrefix:@"~"])
		path = [_home stringByAppendingPathComponent:[path substringFromIndex:1]];
	else if ([path hasPrefix:@"/~"])
		path = [_home stringByAppendingPathComponent:[path substringFromIndex:2]];
	else
		return [aURL absoluteURL];
	path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	return [[NSURL URLWithString:path relativeToURL:aURL] absoluteURL];
}

- (NSString *)stringByAbbreviatingWithTildeInPath:(NSURL *)aURL
{
	NSString *path = [aURL path];
	if (_home && [path hasPrefix:_home])
		path = [path stringByReplacingCharactersInRange:NSMakeRange(0, [_home length]) withString:@"~"];
	return [NSString stringWithFormat:@"%@%s%@%s%@:%@",
	    _user ? _user : @"", _user ? "@" : "", _host, _port ? ":" : "", _port ? _port : @"", path];
}

- (SFTPRequest *)attributesOfItemAtURL:(NSURL *)url
			    onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback
{
	DEBUG(@"url = [%@]", url);
	url = [self normalizeURL:url];

	if (url == nil) {
		responseCallback(nil, nil, [ViError errorWithFormat:@"nil URL passed"]);
		return nil;
	}

	void (^originalCallback)(NSURL *, NSDictionary *, NSError *) = [[responseCallback copy] autorelease];
	SFTPRequest *req = [self addRequest:_remoteVersion == 0 ? SSH2_FXP_STAT_VERSION_0 : SSH2_FXP_LSTAT
				     format:"s", [url path]];
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
	void (^originalCallback)(NSURL *, BOOL, NSError *) = [[responseCallback copy] autorelease];

	return [self attributesOfItemAtURL:url onResponse:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (error) {
			if ([error isFileNotFoundError])
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
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];

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

- (SFTPRequest *)resolveSymlinksInEntries:(NSMutableArray *)entries
			    relativeToURL:(NSURL *)aURL
			     onCompletion:(void (^)(NSArray *, NSError *))completionCallback
{
	void (^originalCallback)(NSArray *, NSError *) = [[completionCallback copy] autorelease];

	__block SFTPRequest *req = nil;
	for (ViFile *file in entries) {
		if (file.targetAttributes)
			continue; // We have already resolved symlinks in this file

		req = [self realpath:file.path onResponse:^(NSString *realPath, NSDictionary *dummyAttributes, NSError *error) {
			[req autorelease];
			NSURL *url = [NSURL URLWithString:realPath relativeToURL:aURL];
			if (error)
				originalCallback(nil, error);
			else if (file.isLink) {
				req.subRequest = [self attributesOfItemAtURL:url
								  onResponse:^(NSURL *normalizedURL, NSDictionary *realAttributes, NSError *error) {
					if (error && ![error isFileNotFoundError])
						originalCallback(nil, error);
					else {
						[file setTargetURL:[self normalizeURL:url]
							attributes:realAttributes ?: [NSDictionary dictionary]];
						req.subRequest = [self resolveSymlinksInEntries:entries
										  relativeToURL:aURL
										   onCompletion:originalCallback];
					}
				}];
			} else {
				[file setTargetURL:[self normalizeURL:url]
					attributes:[NSDictionary dictionary]];
				req.subRequest = [self resolveSymlinksInEntries:entries
								  relativeToURL:aURL
								   onCompletion:originalCallback];
			}
		}];
		[req retain];
		break;
	}

	if (req == nil) {
		DEBUG(@"%s", "resolved all symlinks");
		originalCallback(entries, nil);
	}

	return req;
}

- (SFTPRequest *)contentsOfDirectoryAtURL:(NSURL *)aURL
				onResponse:(void (^)(NSArray *, NSError *))responseCallback
{
	NSURL *url = [self normalizeURL:aURL];

	void (^originalCallback)(NSArray *, NSError *) = [[responseCallback copy] autorelease];

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
		cancelfun = [[cancelfun copy] autorelease];

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
						else {
							openRequest.subRequest = [self resolveSymlinksInEntries:entries
												  relativeToURL:aURL
												   onCompletion:^(NSArray *resolvedEntries, NSError *error) {
								openRequest.subRequest = nil;
								if (error)
									resolvedEntries = nil;
								originalCallback(resolvedEntries, error);
							}];
						}
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
					[entries addObject:[ViFile fileWithURL:[url URLByAppendingPathComponent:filename]
								    attributes:attributes]];
			}

			/* Request another batch of names. */
			SFTPRequest *req = [self addRequest:SSH2_FXP_READDIR format:"d", handle];
			req.onResponse = readfun;
			req.onCancel = cancelfun;
			openRequest.subRequest = req;
		};
		readfun = [[readfun copy] autorelease];

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
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
	SFTPRequest *req = [self addRequest:SSH2_FXP_MKDIR format:"sa", path, [NSDictionary dictionary]];
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
	DEBUG(@"Closing connection %@", _sshPipe);
	[_sshPipe close];
	[_sshPipe release];
	_sshPipe = nil;
	[_ssh_task terminate];
	[_ssh_task release];
	_ssh_task = nil;
	[_errStream close];
	[_errStream release];
	_errStream = nil;
}

- (void)abort
{
	[self close];
	DEBUG(@"cancelling outstanding requests: %@", _requests);
	for (SFTPRequest *req in [_requests objectEnumerator])
		[req cancel];
	[_requests removeAllObjects];
}

- (BOOL)closed
{
	return _sshPipe == nil;
}

- (BOOL)connected
{
	return ![self closed] && _remoteVersion != -1;
}

- (NSString *)title
{
	return [NSString stringWithFormat:@"sftp://%@%s%@%s%@",
	    _user ? _user : @"", _user ? "@" : "", _host, _port ? ":" : "", _port ? _port : @""];
}

- (SFTPRequest *)openFile:(NSString *)path
	       forWriting:(BOOL)isWrite
	   withAttributes:(NSDictionary *)attributes
	       onResponse:(void (^)(NSData *handle, NSError *error))responseCallback
{
	uint32_t mode;
	if (isWrite)
		mode = SSH2_FXF_WRITE|SSH2_FXF_CREAT|SSH2_FXF_EXCL;
	else
		mode = SSH2_FXF_READ;

	void (^originalCallback)(NSData *, NSError *) = [[responseCallback copy] autorelease];

	SFTPRequest *req = [self addRequest:SSH2_FXP_OPEN format:"sua", path, mode, attributes];
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
	void (^originalCallback)(NSURL *, NSDictionary *, NSError *) = [[responseCallback copy] autorelease];
	__block SFTPRequest *statRequest = nil;

	void (^fun)(NSURL *, NSDictionary *, NSError *) = ^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		[statRequest autorelease];
		if (error) {
			originalCallback(url, nil, error);
			return;
		}

		if (![[attributes fileType] isEqualToString:NSFileTypeRegular]) {
			originalCallback(normalizedURL, attributes,
			    [ViError errorWithFormat:@"%@ is not a regular file", [normalizedURL path]]);
			return;
		}

		unsigned long long fileSize = [attributes fileSize]; /* may be zero */
		statRequest.progress = 0.0;

		statRequest.subRequest = [self openFile:[normalizedURL path]
					     forWriting:NO
					 withAttributes:[NSDictionary dictionary]
					     onResponse:^(NSData *handle, NSError *error) {
			__block uint64_t offset = 0;
			__block uint32_t len = _transfer_buflen;

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
			cancelfun = [[cancelfun copy] autorelease];

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
			readfun = [[readfun copy] autorelease];

			/* Dispatch first read request. */
			DEBUG(@"requesting %u bytes at offset %lu", len, offset);
			SFTPRequest *req = [self addRequest:SSH2_FXP_READ format:"dqu", handle, offset, len];
			req.onResponse = readfun;
			req.onCancel = cancelfun;
			statRequest.subRequest = req;
		}];
	};

	statRequest = [self attributesOfItemAtURL:url onResponse:fun];
	return [statRequest retain];
}

- (NSString *)randomFileAtDirectory:(NSString *)aDirectory
{
	char tmp[37];
	uuid_t uuid;
	uuid_generate(uuid);
	uuid_unparse(uuid, tmp);

	return [aDirectory stringByAppendingPathComponent:[NSString stringWithUTF8String:tmp]];
}

- (SFTPRequest *)setAttributes:(NSDictionary *)attributes
		      ofHandle:(NSData *)handle
		    onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
	SFTPRequest *req = [self addRequest:SSH2_FXP_FSETSTAT format:"da", handle, attributes];
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

- (SFTPRequest *)uploadData:(NSData *)data
		     toFile:(NSString *)path
	     withAttributes:(NSDictionary *)attributes
		 onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
	__block SFTPRequest *openRequest = nil;

	void (^fun)(NSData *, NSError *) = ^(NSData *handle, NSError *error) {
		[openRequest autorelease];
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
		cancelfun = [[cancelfun copy] autorelease];

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
				DEBUG(@"finished uploading %lu bytes, setting file attributes", [data length]);
				openRequest.subRequest = [self setAttributes:attributes
								    ofHandle:handle
								  onResponse:^(NSError *error) {
					DEBUG(@"%s", "finished setting attributes, closing file");
					openRequest.subRequest = [self closeHandle:handle
									onResponse:^(NSError *error) {
						openRequest.subRequest = nil;
						originalCallback(error);
					}];
				}];
				return;
			}

			/* Dispatch next read request. */
			uint32_t len = _transfer_buflen;
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
		writefun = [[writefun copy] autorelease];

		/* Dispatch first read request. */
		uint32_t len = _transfer_buflen;
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

	openRequest = [self openFile:path forWriting:YES withAttributes:attributes onResponse:fun];

	return [openRequest retain];
}

- (SFTPRequest *)removeItemAtPath:(NSString *)path
		       onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
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
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
	NSMutableArray *mutableURLs = [[urls mutableCopy] autorelease];

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

- (SFTPRequest *)moveItemAtURL:(NSURL *)srcURL
			 toURL:(NSURL *)dstURL
		    onResponse:(void (^)(NSURL *, NSError *))responseCallback
{
	void (^originalCallback)(NSURL *, NSError *) = [[responseCallback copy] autorelease];
	SFTPRequest *req = [self addRequest:SSH2_FXP_RENAME format:"ss", [srcURL path], [dstURL path]];
	req.onResponse = ^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectStatus:SSH2_FX_OK error:&error])
			originalCallback(nil, error);
		else {
			req.subRequest = [self realpath:[dstURL path] onResponse:^(NSString *realPath, NSDictionary *dummyAttributes, NSError *error) {
				if (error)
					originalCallback(nil, error);
				else
					originalCallback([[NSURL URLWithString:realPath relativeToURL:dstURL] absoluteURL], nil);
			}];
		}
	};
	req.onCancel = ^(SFTPRequest *req) { originalCallback(nil, [ViError operationCancelled]); };

	return req;
}

- (SFTPRequest *)renameItemAtPath:(NSString *)oldPath
			   toPath:(NSString *)newPath
		       onResponse:(void (^)(NSError *))responseCallback
{
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
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
	void (^originalCallback)(NSError *) = [[responseCallback copy] autorelease];
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
			[renameRequest autorelease];
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
		[renameRequest retain];
	}

	return renameRequest;
}

- (SFTPRequest *)writeDataSafely:(NSData *)data
			   toURL:(NSURL *)aURL
		      onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback
{
	NSURL *url = [self normalizeURL:aURL];

	void (^originalCallback)(NSURL *, NSDictionary *, NSError *) = [[responseCallback copy] autorelease];
	__block SFTPRequest *uploadRequest = nil;

	uploadRequest = [self attributesOfItemAtURL:url
					 onResponse:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		DEBUG(@"got attributes %@, error %@ for url %@", attributes, error, normalizedURL);
		[uploadRequest autorelease];
		if (error == nil && attributes) {
			/* Upload to a random file, then rename it to our destination filename. */
			NSString *randomFilename = [self randomFileAtDirectory:[[url path] stringByDeletingLastPathComponent]];
			/* Don't preserve the file modification date. We're like, uh, modifing the file. */
			[(NSMutableDictionary *)attributes removeObjectForKey:NSFileModificationDate];
			uploadRequest.subRequest = [self uploadData:data
							     toFile:randomFilename
						     withAttributes:attributes
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
		} else if ([error isFileNotFoundError]) {
			uploadRequest.subRequest = [self uploadData:data toFile:[url path] withAttributes:[NSDictionary dictionary] onResponse:^(NSError *error) {
				/* It was a new file, upload successful. Or other error. */
				if (error) {
					uploadRequest.subRequest = nil;
					originalCallback(url, nil, error);
					return;
				}

				uploadRequest.subRequest = [self attributesOfItemAtURL:url
									    onResponse:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
					uploadRequest.subRequest = nil;
					originalCallback(url, attributes, error);
				}];
			}];
		} else {
			uploadRequest.subRequest = nil;
			originalCallback(url, nil, error);
		}
	}];

	return [uploadRequest retain];
}

- (NSString *)stderr
{
	NSString *str;
	char *buf;

	str = [[[NSString alloc] initWithData:_errbuf encoding:NSUTF8StringEncoding] autorelease];
	if (str)
		return str;

	/* Not valid UTF-8, convert to ASCII */

	if ((buf = malloc(4 * [_errbuf length] + 1)) == NULL) {
		return @"";
	}

	strvisx(buf, [_errbuf bytes], [_errbuf length], VIS_NOSLASH);
	str = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
	free(buf);
	return str;
}

@end

