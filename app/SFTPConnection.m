#define FORCE_DEBUG
#import "SFTPConnection.h"
#import "ViError.h"

#include "sys_queue.h"
#include <sys/socket.h>

#include <uuid/uuid.h>
#include <vis.h>

#include "log.h"
#include "xmalloc.h"
#include "atomicio.h"
#include "logging.h"

@implementation SFTPDirectoryEntry

@synthesize filename;

- (SFTPDirectoryEntry *)initWithFilename:(const char *)aFilename attributes:(Attrib *)a
{
	self = [super init];
	if (self)
	{
		filename = [NSString stringWithCString:aFilename encoding:NSUTF8StringEncoding]; // XXX: what encoding?
		if (filename == nil)
			filename = [NSString stringWithCString:aFilename encoding:NSISOLatin1StringEncoding];
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

#pragma mark -


@implementation SFTPRequest

+ (SFTPRequest *)requestWithId:(uint32_t)reqId onResponse:(void (^)(SFTPMessage *))aCallback
{
	return [[SFTPRequest alloc] initWithId:reqId onResponse:aCallback];
}

- (SFTPRequest *)initWithId:(uint32_t)reqId onResponse:(void (^)(SFTPMessage *))aCallback
{
	if ((self = [super init]) != nil) {
		requestId = reqId;
		DEBUG(@"copying block %p", aCallback);
		responseCallback = Block_copy(aCallback);
	}
	return self;
}

- (void)response:(SFTPMessage *)msg
{
	responseCallback(msg);
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

		if (type == SSH2_FXP_VERSION)
			DEBUG(@"got server version %u", requestId);
		else
			DEBUG(@"got %i message with request id %u", type, requestId);
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

	if (outError) {
		if (status != 0) {
			if (errmsg)
				*outError = [ViError errorWithFormat:@"%@", errmsg];
			else
				*outError = [ViError errorWithFormat:@"%s", fx2txt(status)];
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
		if (S_ISREG(perm))
			fileType = NSFileTypeRegular;
		else if (S_ISDIR(perm))
			fileType = NSFileTypeDirectory;
		else if (S_ISLNK(perm))
			fileType = NSFileTypeSymbolicLink;
		else if (S_ISSOCK(perm))
			fileType = NSFileTypeSocket;
		else if (S_ISBLK(perm))
			fileType = NSFileTypeBlockSpecial;
		else if (S_ISCHR(perm))
			fileType = NSFileTypeCharacterSpecial;
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

- (void)readStandardError:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSData *data = [userInfo objectForKey:NSFileHandleNotificationDataItem];
	if (data == nil) {
		int err = [[userInfo objectForKey:@"NSFileHandleError"] intValue];
		INFO(@"error: %s", strerror(err));
		[self close];
	} else if ([data length] == 0) {
		INFO(@"End-of-file on ssh connection %@", [self hostWithUser]);
		[self close];
	} else {
		[errbuf appendData:data];
#ifndef NO_DEBUG
		NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		DEBUG(@"read data %@", str);
#endif

		[[ssh_error fileHandleForReading] readInBackgroundAndNotify];
	}
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
				DEBUG(@"got response %@ to request %@", request, req_id);
				[request response:msg];
				[requests removeObjectForKey:req_id];
			}
		}
	}
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event
{
	DEBUG(@"got event %lu on stream %@", event, stream);

	const void *ptr;
	NSUInteger len;

	switch (event) {
	case NSStreamEventNone:
	case NSStreamEventOpenCompleted:
	default:
		break;
	case NSStreamEventHasBytesAvailable:
		[sshPipe getBuffer:&ptr length:&len];
		DEBUG(@"got %lu bytes", len);
		if (len > 0) {
			[inbuf appendBytes:ptr length:len];
			[self dispatchMessages];
		}
		break;
	case NSStreamEventHasSpaceAvailable:
		break;
	case NSStreamEventErrorOccurred:
		INFO(@"error on stream %@: %@", stream, [stream streamError]);
		[self close];
		break;
	case NSStreamEventEndEncountered:
		DEBUG(@"EOF on stream %@", stream);
		[self close];
		break;
	}
}

- (void)addRequestOfType:(uint8_t)requestType
	       requestId:(uint32_t)requestId
		    data:(NSData *)requestData
	      onResponse:(void (^)(SFTPMessage *))responseCallback
{
	DEBUG(@"queueing request type %d with id %u and %lu bytes payload",
	    requestType, requestId, [requestData length]);

	struct head {
		uint32_t len;
		uint8_t type;
		uint32_t reqid;
	} __attribute__ ((__packed__));

	struct head head;
	head.len = htonl([requestData length] + 5);
	head.type = requestType;
	head.reqid = htonl(requestId);
	NSData *headData = [NSData dataWithBytes:&head length:sizeof(head)];

	[sshPipe writeData:headData];
	if (requestData)
		[sshPipe writeData:requestData];

	SFTPRequest *req = [SFTPRequest requestWithId:requestId onResponse:responseCallback];
	if (requestType == SSH2_FXP_INIT)
		initRequest = req;
	else
		[requests setObject:req forKey:[NSNumber numberWithUnsignedInt:requestId]];
}

- (void)addRequestOfType:(uint8_t)requestType
		    data:(NSData *)requestData
	      onResponse:(void (^)(SFTPMessage *))responseCallback
{
	[self addRequestOfType:requestType
		     requestId:++nextRequestId
			  data:requestData
		    onResponse:responseCallback];
}

- (void)addRequestOfType:(uint8_t)requestType
		  string:(id)requestString
	      onResponse:(void (^)(SFTPMessage *))responseCallback
{
	const void *string;
	uint32_t len;

	if ([requestString isKindOfClass:[NSString class]]) {
		string = [(NSString *)requestString UTF8String];
		len = (uint32_t)strlen(string); /* XXX: doesn't allow null bytes */
	} else if ([requestString isKindOfClass:[NSData class]]) {
		string = [(NSData *)requestString bytes];
		len = (uint32_t)[(NSData *)requestString length];
	} else {
		INFO(@"internal error, got string %@", requestString);
		return;
	}

	NSMutableData *data = [NSMutableData dataWithCapacity:4 + len];
	uint32_t tmp = CFSwapInt32HostToBig(len);
	[data appendBytes:&tmp length:sizeof(tmp)];
	[data appendBytes:string length:len];

	[self addRequestOfType:requestType
			  data:data
		    onResponse:responseCallback];
}

- (void)addRequestOfType:(uint8_t)requestType
		  string:(NSString *)requestString
	      attributes:(NSDictionary *)attributes
	      onResponse:(void (^)(SFTPMessage *))responseCallback
{
	const void *string;
	uint32_t len;

	if ([requestString isKindOfClass:[NSString class]]) {
		string = [(NSString *)requestString UTF8String];
		len = (uint32_t)strlen(string); /* XXX: doesn't allow null bytes */
	} else if ([requestString isKindOfClass:[NSData class]]) {
		string = [(NSData *)requestString bytes];
		len = (uint32_t)[(NSData *)requestString length];
	} else {
		INFO(@"internal error, got string %@", requestString);
		return;
	}

	NSMutableData *data = [NSMutableData dataWithCapacity:4 + len];
	uint32_t tmp = CFSwapInt32HostToBig(len);
	[data appendBytes:&tmp length:sizeof(tmp)];
	[data appendBytes:string length:len];

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

	[self addRequestOfType:requestType
			  data:data
		    onResponse:responseCallback];
}

- (void)realpath:(NSString *)path
      onResponse:(void (^)(NSString *, NSDictionary *, NSError *))responseCallback
{
	[self addRequestOfType:SSH2_FXP_REALPATH
			string:path
		    onResponse:^(SFTPMessage *msg) {
		uint32_t count;
		NSError *error;

		if (![msg expectType:SSH2_FXP_NAME error:error]) {
			responseCallback(nil, nil, error);
			[self close];
		} else if (![msg getUnsigned:&count]) {
			responseCallback(nil, nil, [ViError errorWithFormat:@"SFTP protocol error"]);
			[self close];
		} else if (count != 1) {
			responseCallback(nil, nil, [ViError errorWithFormat:@"Got multiple names (%d) from SSH_FXP_REALPATH", count]);
		} else {
			NSString *filename;
			NSDictionary *attributes;

			if (![msg getString:&filename] || ![msg getString:NULL] || ![msg getAttributes:&attributes]) {
				responseCallback(nil, nil, [ViError errorWithFormat:@"SFTP protocol error"]);
				[self close];
			} else {
				DEBUG(@"SSH_FXP_REALPATH %@ -> %@", path, filename);
				DEBUG(@"attributes = %@", attributes);
				responseCallback(filename, attributes, nil);
			}
		}
	}];
}

- (void)initConnection
{
	remoteVersion = -1;

	[self addRequestOfType:SSH2_FXP_INIT
		     requestId:SSH2_FILEXFER_VERSION
			  data:nil
		    onResponse:^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectType:SSH2_FXP_VERSION error:&error]) {
			INFO(@"got error %@", error);
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
			if ([name isEqualToString:@"posix-rename@openssh.com"] && [value isEqualToString:@"1"]) {
				exts |= SFTP_EXT_POSIX_RENAME;
				known = YES;
			} else if ([name isEqualToString:@"statvfs@openssh.com"] && [value isEqualToString:@"2"]) {
				exts |= SFTP_EXT_STATVFS;
				known = YES;
			} else if ([name isEqualToString:@"fstatvfs@openssh.com"] && [value isEqualToString:@"2"]) {
				exts |= SFTP_EXT_FSTATVFS;
				known = YES;
			}

			if (known)
				DEBUG(@"Server supports extension \"%@\" revision %@", name, value);
			else
				DEBUG(@"Unrecognised server extension \"%@\"", name);
		}

		/* Some filexfer v.0 servers don't support large packets */
		transfer_buflen = 32768;
		if (version == 0)
			transfer_buflen = MIN(transfer_buflen, 20480);
	}];

	[self realpath:@"." onResponse:^(NSString *filename, NSDictionary *attributes, NSError *error) {
		if (error)
			INFO(@"failed to read home directory: %@", [error localizedDescription]);
		else {
			DEBUG(@"resolved home directory to %@", filename);
			home = filename;
		}
	}];
}

- (SFTPConnection *)initWithHost:(NSString *)hostname
			    user:(NSString *)username
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
#ifndef NO_DEBUG
		[arguments addObject:@"-vvv"];
#endif
		[arguments addObject:@"-s"];
		if ([username length] > 0)
			[arguments addObject:[NSString stringWithFormat:@"%@@%@", username, hostname]];
		else
			[arguments addObject:hostname];
		[arguments addObject:@"sftp"];

		DEBUG(@"ssh arguments: %@", arguments);
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

		inbuf = [NSMutableData data];
		errbuf = [NSMutableData data];

		[[ssh_error fileHandleForReading] readInBackgroundAndNotify];
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(readStandardError:)
							     name:NSFileHandleReadCompletionNotification
							   object:[ssh_error fileHandleForReading]];

		sshPipe = [[ViBufferedStream alloc] initWithTask:ssh_task];
		[sshPipe setDelegate:self];
		[sshPipe scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

		host = hostname;
		user = username;

		directoryCache = [NSMutableDictionary dictionary];
		requests = [NSMutableDictionary dictionary];

		[self initConnection];
	}
	return self;
}

/* FIXME: try attributes in directoryCache first? */
- (void)attributesOfItemAtPath:(NSString *)path
		    onResponse:(void (^)(NSDictionary *, NSError *))responseCallback
{
	[self addRequestOfType:remoteVersion == 0 ? SSH2_FXP_STAT_VERSION_0 : SSH2_FXP_STAT
			string:path
		    onResponse:^(SFTPMessage *msg) {
		NSDictionary *attributes;
		NSError *error;
		if (![msg expectType:SSH2_FXP_ATTRS error:&error])
			responseCallback(nil, error);
		else if (![msg getAttributes:&attributes])
			responseCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
		else {
			DEBUG(@"got attributes %@", attributes);
			responseCallback(attributes, nil);
		}
	}];
}

- (void)fileExistsAtPath:(NSString *)path
	      onResponse:(void (^)(BOOL, BOOL, NSError *))responseCallback
{
	DEBUG(@"path = [%@]", path);

	if (path == nil || [path isEqualToString:@""]) {
		/* This is the home directory. */
		responseCallback(YES, YES, nil);
		return;
	}

	[self attributesOfItemAtPath:path onResponse:^(NSDictionary *attributes, NSError *error) {
		if (error) {
			if ([error code] == SSH2_FX_NO_SUCH_FILE)
				error = nil;
			responseCallback(NO, NO, error);
			return;
		}

		uint32_t perms = [attributes filePosixPermissions];
		if (perms == 0) {
			/* Attributes didn't include permissions, probably because we couldn't read them. */
			responseCallback(NO, NO, [ViError errorWithFormat:@"Permission denied"]);
		} else {
			DEBUG(@"got permissions %06o", perms);
			responseCallback(YES, [[attributes fileType] isEqualToString:NSFileTypeDirectory], nil);
		}
	}];
}

- (void)closeHandle:(NSData *)handle
	    onError:(void (^)(NSError *))errorCallback
	  onSuccess:(void (^)(SFTPMessage *))successCallback
{
	[self addRequestOfType:SSH2_FXP_CLOSE
			string:handle
		    onResponse:^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectStatus:SSH2_FX_OK error:&error])
			errorCallback(error);
		else
			successCallback(msg);
	}];
}

- (void)contentsOfDirectoryAtPath:(NSString *)path
		       onResponse:(void (^)(NSArray *, NSError *))responseCallback
{
	if (path == nil || [path isEqualToString:@""]) {
		/* This is the home directory. */
		path = home;
		if (path == nil)
			path = @"";
	}

	NSArray *contents = [directoryCache objectForKey:path];
	if (contents) {
		responseCallback(contents, nil);
		return;
	}

	[self addRequestOfType:SSH2_FXP_OPENDIR
			string:path
		    onResponse:^(SFTPMessage *msg) {
		NSData *handle;
		NSError *error;
		if (![msg expectType:SSH2_FXP_HANDLE error:&error])
			responseCallback(nil, error);
		else if (![msg getBlob:&handle])
			responseCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
		else {
			DEBUG(@"got handle [%@]", handle);
			NSMutableArray *entries = [NSMutableArray array];

			/* Response callback that repeatedly calls SSH2_FXP_READDIR. */
			__block void (^readfun)(SFTPMessage *);
			readfun = Block_copy(^(SFTPMessage *msg) {
				uint32_t count;
				if (msg.type == SSH2_FXP_STATUS) {
					uint32_t status;
					if (![msg getUnsigned:&status])
						responseCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
					else if (status == SSH2_FX_EOF) {
						[self closeHandle:handle
							  onError:^(NSError *error) { responseCallback(nil, error); }
							onSuccess:^(SFTPMessage *msg) {
								[directoryCache setObject:entries forKey:path];
								responseCallback(entries, nil);
						}];
					} else
						responseCallback(nil, [ViError errorWithFormat:@"%s", fx2txt(status)]);
				} else if (msg.type != SSH2_FXP_NAME || ![msg getUnsigned:&count]) {
					responseCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
				} else {
					for (uint32_t i = 0; i < count; i++) {
						NSString *filename;
						NSDictionary *attributes;
						if (![msg getString:&filename] ||
						    ![msg getString:NULL] ||
						    ![msg getAttributes:&attributes]) {
							responseCallback(nil, [ViError errorWithFormat:@"SFTP protocol error"]);
							return;
						}
						DEBUG(@"got file %@, attributes %@", filename, attributes);

						if ([filename rangeOfString:@"/"].location != NSNotFound)
							INFO(@"Ignoring suspect path \"%@\" during readdir of \"%s\"", filename, path);
						else
							[entries addObject:[NSArray arrayWithObjects:filename, attributes, nil]];
					}

					/* Request another batch of names. */
					[self addRequestOfType:SSH2_FXP_READDIR
							string:handle
						    onResponse:readfun];
				}
			});

			/* Request a batch of names. */
			[self addRequestOfType:SSH2_FXP_READDIR
					string:handle
				    onResponse:readfun];
		}
	}];
}

- (void)createDirectory:(NSString *)path
	     onResponse:(void (^)(NSError *))responseCallback
{
	[self addRequestOfType:SSH2_FXP_MKDIR
			string:path
		    attributes:[NSDictionary dictionary]
		    onResponse:^(SFTPMessage *msg) {
		NSError *error;
		if (![msg expectStatus:SSH2_FX_OK error:&error])
			responseCallback(error);
		else
			responseCallback(nil);
	}];
}

- (void)flushDirectoryCache
{
	directoryCache = [NSMutableDictionary dictionary];
}

- (void)close
{
	INFO(@"Closing connection %@", sshPipe);
	INFO(@"outstanding requests: %@", requests); // XXX: cancel them!
	[sshPipe close];
	sshPipe = nil;
	[ssh_task terminate];
	ssh_task = nil;
	ssh_input = ssh_output = ssh_error = nil;
}

- (BOOL)closed
{
	return sshPipe == nil;
}

/* FIXME: leaks the 'requests' list on error paths
 */
- (void)dataWithContentsOfFile:(NSString *)path
			onData:(void (^)(NSData *))dataCallback
		    onResponse:(void (^)(NSError *))responseCallback
{
	[self addRequestOfType:SSH2_FXP_OPEN
			string:path
		    onResponse:^(SFTPMessage *msg) {
	}];

#if 0
	NSMutableData *output = [NSMutableData data];

	const char *remote_path = [path UTF8String];
	if (remote_path == NULL) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Invalid filename"];
		return nil;
	}

	Attrib junk, *a;
	Buffer msg;
	char *handle;
	u_int status = 0;
	int read_error;
	u_int64_t offset, size;
	char type;
	u_int handle_len, req_id, buflen, num_req, max_req;
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

	buflen = transfer_buflen;
	buffer_init(&msg);

	/* Send open request */
	req_id = msg_id++;
	buffer_put_char(&msg, SSH2_FXP_OPEN);
	buffer_put_int(&msg, req_id);
	buffer_put_cstring(&msg, remote_path);
	buffer_put_int(&msg, SSH2_FXF_READ);
	attrib_clear(&junk); /* Send empty attributes */
	encode_attrib(&msg, &junk);
	send_msg(fd_out, &msg);
	DEBUG(@"Sent message SSH2_FXP_OPEN I:%u P:%@", req_id, path);

	if (![self getHandle:&handle length:&handle_len expectingID:req_id error:outError]) {
		buffer_free(&msg);
		return nil;
	}

	/* Read from remote and write to NSData */
	read_error = num_req = 0;
	offset = 0;
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
			req->req_id = msg_id++;
			req->len = buflen;
			req->offset = offset;
			offset += buflen;
			num_req++;
			TAILQ_INSERT_TAIL(&requests, req, tq);
			send_read_request(fd_out, req->req_id, req->offset,
			    req->len, handle, handle_len);
		}

		buffer_clear(&msg);

		if (![self readMsg:&msg error:outError] ||
		    ![self readChar:&type from:&msg error:outError] ||
		    ![self readInt:&req_id from:&msg error:outError]) {
			buffer_free(&msg);
			return nil;
		}

		DEBUG(@"Received reply T:%u I:%u R:%d", type, req_id, max_req);

		/* Find the request in our queue */
		for (req = TAILQ_FIRST(&requests);
		    req != NULL && req->req_id != req_id;
		    req = TAILQ_NEXT(req, tq))
			;
		if (req == NULL) {
			if (outError)
				*outError = [ViError errorWithFormat:
				    @"Unexpected reply %u", req_id];
			[self close];
			return nil;
		}

		switch (type) {
		case SSH2_FXP_STATUS:
			if (![self readInt:&status from:&msg error:outError]) {
				buffer_free(&msg);
				return nil;
			}
			if (status != SSH2_FX_EOF)
				read_error = 1;
			max_req = 0;
			TAILQ_REMOVE(&requests, req, tq);
			xfree(req);
			num_req--;
			break;
		case SSH2_FXP_DATA:
			if (![self readString:&data length:&len from:&msg error:outError]) {
				buffer_free(&msg);
				return nil;
			}
			DEBUG(@"Received data %llu -> %llu",
			    (unsigned long long)req->offset,
			    (unsigned long long)req->offset + len - 1);
			if (len > req->len) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Received more data than asked for %u > %u", len, req->len];
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
				req->req_id = msg_id++;
				req->len -= len;
				req->offset += len;
				send_read_request(fd_out, req->req_id,
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
				} else if (max_req <= NUM_REQUESTS) {
					++max_req;
				}
			}
			break;
		default:
			if (outError)
				*outError = [ViError errorWithFormat:
				    @"Expected SSH2_FXP_DATA(%u) packet, got %u",
				    SSH2_FXP_DATA, type];
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
			*outError = [ViError errorWithFormat:
			    @"Couldn't read from remote file \"%@\" : %s",
			    path, fx2txt(status)];
	}

	[self closeHandle:handle length:handle_len error:outError];

	buffer_free(&msg);
	xfree(handle);

	return output;
#endif
}

#if 0
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
#endif

- (BOOL)uploadData:(NSData *)data
            toFile:(NSString *)path
    withAttributes:(Attrib *)remote_attribs
             error:(NSError **)outError
{
	if (outError)
		*outError = [ViError errorWithFormat:@"not implemented"];
	return NO;

#if 0
	NSUInteger dataOffset = 0;
	const void *bytes;

	const char *remote_path = [path fileSystemRepresentation];
	if (remote_path == NULL)
		return NO;

	u_int status = SSH2_FX_OK;
	char type;
	u_int handle_len, req_id;
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
	req_id = msg_id++;
	buffer_put_char(&msg, SSH2_FXP_OPEN);
	buffer_put_int(&msg, req_id);
	buffer_put_cstring(&msg, remote_path);
	buffer_put_int(&msg, SSH2_FXF_WRITE|SSH2_FXF_CREAT|SSH2_FXF_TRUNC);
	encode_attrib(&msg, remote_attribs);
	send_msg(fd_out, &msg);
	DEBUG(@"Sent message SSH2_FXP_OPEN I:%u P:%@", req_id, path);

	buffer_clear(&msg);

	if (![self getHandle:&handle length:&handle_len expectingID:req_id error:outError]) {
		buffer_free(&msg);
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
			len = transfer_buflen;
			if (dataOffset + len > [data length])
				len = (int)([data length]- dataOffset);
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
			send_msg(fd_out, &msg);
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
		    req_id - ackid >= NUM_REQUESTS) {
			u_int r_id;

			buffer_clear(&msg);
			if (![self readMsg:&msg error:outError] ||
			    ![self readChar:&type from:&msg error:outError] ||
			    ![self readInt:&r_id from:&msg error:outError]) {
				buffer_free(&msg);
				return NO;
			}

			if (type != SSH2_FXP_STATUS) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Expected SSH2_FXP_STATUS(%d) packet, got %d",
					    SSH2_FXP_STATUS, type];
				goto fail;
			}

			if (![self readInt:&status from:&msg error:outError]) {
				buffer_free(&msg);
				return NO;
			}
			DEBUG(@"SSH2_FXP_STATUS %d", status);

			/* Find the request in our queue */
			for (ack = TAILQ_FIRST(&acks);
			    ack != NULL && ack->req_id != r_id;
			    ack = TAILQ_NEXT(ack, tq))
				;
			if (ack == NULL) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Can't find request for ID %u", r_id];
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
			*outError = [ViError errorWithFormat:
			    @"Couldn't write to remote file \"%@\": %s",
			    path, fx2txt(status)];
		goto fail;
	}

	goto done;

fail:
	status = -1;
done:
	if (![self closeHandle:handle length:handle_len error:outError])
		status = -1;

	xfree(handle);

	return status == 0 ? YES : NO;
#endif
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)outError
{
	if (outError)
		*outError = [ViError errorWithFormat:@"not implemented"];
	return NO;

#if 0
	u_int status, req_id;

	const char *utf8path = [path UTF8String];
	DEBUG(@"Sending SSH2_FXP_REMOVE \"%@\"", path);

	req_id = msg_id++;
	send_string_request(fd_out, req_id, SSH2_FXP_REMOVE, utf8path, (u_int)strlen(utf8path));
	if (![self readStatus:&status expectingID:req_id error:outError])
		return NO;

	if (status != SSH2_FX_OK) {
		if (outError)
			*outError = [ViError errorWithFormat:
			    @"Couldn't delete file: %s", fx2txt(status)];
		return NO;
	}
	return YES;
#endif
}

- (BOOL)renameItemAtPath:(NSString *)oldPath
                  toPath:(NSString *)newPath
                   error:(NSError **)outError
{
	if (outError)
		*outError = [ViError errorWithFormat:@"not implemented"];
	return NO;

#if 0
	Buffer msg;
	u_int status, req_id;

	const char *old_path = [oldPath UTF8String];
	const char *new_path = [newPath UTF8String];
	if (old_path == NULL || new_path == NULL)
		return NO;

	buffer_init(&msg);

	/* Send rename request */
	req_id = msg_id++;
	if ((exts & SFTP_EXT_POSIX_RENAME)) {
		buffer_put_char(&msg, SSH2_FXP_EXTENDED);
		buffer_put_int(&msg, req_id);
		buffer_put_cstring(&msg, "posix-rename@openssh.com");
	} else {
		buffer_put_char(&msg, SSH2_FXP_RENAME);
		buffer_put_int(&msg, req_id);
	}
	buffer_put_cstring(&msg, old_path);
	buffer_put_cstring(&msg, new_path);
	send_msg(fd_out, &msg);
/*	DEBUG(@"Sent message %s \"%s\" -> \"%s\"",
	    (exts & SFTP_EXT_POSIX_RENAME) ? "posix-rename@openssh.com" :
	    "SSH2_FXP_RENAME", oldPath, newPath);
 */
	buffer_free(&msg);

	if (![self readStatus:&status expectingID:req_id error:outError])
		return NO;
	if (status != SSH2_FX_OK) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Couldn't rename file \"%@\" to \"%@\": %s", oldPath, newPath, fx2txt(status)];
		return NO;
	}

	return YES;
#endif
}

- (BOOL)hasPosixRename
{
	return ((exts & SFTP_EXT_POSIX_RENAME) == SFTP_EXT_POSIX_RENAME);
}

- (BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)outError
{
	if (outError)
		*outError = [ViError errorWithFormat:@"not implemented"];
	return NO;

#if 0
	Attrib *attr = [self stat:path error:nil];

	if (attr == NULL) {
		/* New file. */
		return [self uploadData:data toFile:path withAttributes:attr error:outError];
	}

	NSString *tmp = [self randomFileAtDirectory:[path stringByDeletingLastPathComponent]];

	if (![self uploadData:data toFile:tmp withAttributes:attr error:outError])
		return NO;

	if ([self hasPosixRename]) {
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
#endif
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

