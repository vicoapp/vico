#import "ViBufferedStream.h"
#import "ViURLManager.h"

#include <sys/stat.h>

/*
 * draft-ietf-secsh-filexfer-02
 */

/* version */
#define	SSH2_FILEXFER_VERSION		3

/* client to server */
#define SSH2_FXP_INIT			1
#define SSH2_FXP_OPEN			3
#define SSH2_FXP_CLOSE			4
#define SSH2_FXP_READ			5
#define SSH2_FXP_WRITE			6
#define SSH2_FXP_LSTAT			7
#define SSH2_FXP_STAT_VERSION_0		7
#define SSH2_FXP_FSTAT			8
#define SSH2_FXP_SETSTAT		9
#define SSH2_FXP_FSETSTAT		10
#define SSH2_FXP_OPENDIR		11
#define SSH2_FXP_READDIR		12
#define SSH2_FXP_REMOVE			13
#define SSH2_FXP_MKDIR			14
#define SSH2_FXP_RMDIR			15
#define SSH2_FXP_REALPATH		16
#define SSH2_FXP_STAT			17
#define SSH2_FXP_RENAME			18
#define SSH2_FXP_READLINK		19
#define SSH2_FXP_SYMLINK		20

/* server to client */
#define SSH2_FXP_VERSION		2
#define SSH2_FXP_STATUS			101
#define SSH2_FXP_HANDLE			102
#define SSH2_FXP_DATA			103
#define SSH2_FXP_NAME			104
#define SSH2_FXP_ATTRS			105

#define SSH2_FXP_EXTENDED		200
#define SSH2_FXP_EXTENDED_REPLY		201

/* attributes */
#define SSH2_FILEXFER_ATTR_SIZE		0x00000001
#define SSH2_FILEXFER_ATTR_UIDGID	0x00000002
#define SSH2_FILEXFER_ATTR_PERMISSIONS	0x00000004
#define SSH2_FILEXFER_ATTR_ACMODTIME	0x00000008
#define SSH2_FILEXFER_ATTR_EXTENDED	0x80000000

/* portable open modes */
#define SSH2_FXF_READ			0x00000001
#define SSH2_FXF_WRITE			0x00000002
#define SSH2_FXF_APPEND			0x00000004
#define SSH2_FXF_CREAT			0x00000008
#define SSH2_FXF_TRUNC			0x00000010
#define SSH2_FXF_EXCL			0x00000020

/* statvfs@openssh.com f_flag flags */
#define SSH2_FXE_STATVFS_ST_RDONLY	0x00000001
#define SSH2_FXE_STATVFS_ST_NOSUID	0x00000002

/* status messages */
#define SSH2_FX_OK			0
#define SSH2_FX_EOF			1
#define SSH2_FX_NO_SUCH_FILE		2
#define SSH2_FX_PERMISSION_DENIED	3
#define SSH2_FX_FAILURE			4
#define SSH2_FX_BAD_MESSAGE		5
#define SSH2_FX_NO_CONNECTION		6
#define SSH2_FX_CONNECTION_LOST		7
#define SSH2_FX_OP_UNSUPPORTED		8
/* The rest are defined in version 6 of the protocol. */
#define SSH2_FX_INVALID_HANDLE		9
#define SSH2_FX_NO_SUCH_PATH		10
#define SSH2_FX_FILE_ALREADY_EXISTS	11
#define SSH2_FX_WRITE_PROTECT		12
#define SSH2_FX_NO_MEDIA		13
#define SSH2_FX_NO_SPACE_ON_FILESYSTEM	14
#define SSH2_FX_QUOTA_EXCEEDED		15
#define SSH2_FX_UNKNOWN_PRINCIPLE	16
#define SSH2_FX_LOCK_CONFlICT		17
#define SSH2_FX_MAX			18

#pragma mark -

@interface SFTPMessage : NSObject
{
	uint8_t		 type;
	uint32_t	 requestId;
	NSData		*data;
	const void	*ptr;
}
@property (readonly) uint8_t type;
@property (readonly) uint32_t requestId;
@property (readonly) NSData *data;
+ (SFTPMessage *)messageWithData:(NSData *)someData;
- (SFTPMessage *)initWithData:(NSData *)someData;

- (NSInteger)left;
- (void)reset;
- (BOOL)getString:(NSString **)ret;
- (BOOL)getByte:(uint8_t *)ret;
- (BOOL)getUnsigned:(uint32_t *)ret;
- (BOOL)getInt64:(int64_t *)ret;
- (BOOL)getAttributes:(NSDictionary **)ret;
@end

#pragma mark -

@class SFTPConnection;

@interface SFTPRequest : NSObject <ViDeferred>
{
	uint32_t requestId;
	uint32_t requestType;
	void (^responseCallback)(SFTPMessage *);
	void (^cancelCallback)(SFTPRequest *);
	SFTPConnection *connection;
	BOOL cancelled;
	SFTPRequest *subRequest;
	CGFloat progress;
	id<ViDeferredDelegate> delegate;
}
@property (copy) void (^onResponse)(SFTPMessage *);
@property (copy) void (^onCancel)(SFTPRequest *);
@property (readwrite, assign) SFTPRequest *subRequest;
@property (readwrite) BOOL cancelled;
@property (readwrite) CGFloat progress;
@property (readonly) uint32_t requestId;

+ (SFTPRequest *)requestWithId:(uint32_t)reqId
			ofType:(uint32_t)type
		  onConnection:(SFTPConnection *)aConnection;
- (SFTPRequest *)initWithId:(uint32_t)reqId
		     ofType:(uint32_t)type
	       onConnection:(SFTPConnection *)aConnection;

- (void)response:(SFTPMessage *)msg;
- (void)cancel;
@end

#pragma mark -

@interface SFTPConnection : NSObject <NSStreamDelegate>
{
	NSString *host;
	NSString *user;
	NSString *home;		/* home directory == current directory on connect */

	id delegate;

	NSTask *ssh_task;
	NSPipe *ssh_input;
	NSPipe *ssh_output;
	NSPipe *ssh_error;

	int remoteVersion;

	/* Outstanding requests, keyed on request ID. */
	NSMutableDictionary *requests;
	/* The initial INIT request does not have a request ID. */
	SFTPRequest *initRequest;

	NSMutableData *inbuf;
	NSMutableData *errbuf;

	ViBufferedStream *sshPipe;
	ViBufferedStream *errStream;

	uint32_t nextRequestId;
	uint32_t transfer_buflen;

#define SFTP_EXT_POSIX_RENAME	0x00000001
#define SFTP_EXT_STATVFS	0x00000002
#define SFTP_EXT_FSTATVFS	0x00000004
	uint32_t exts;

	NSMutableDictionary *directoryCache;
}

@property(readonly) NSString *host;
@property(readonly) NSString *user;
@property(readonly) NSString *home;

- (SFTPConnection *)initWithHost:(NSString *)hostname user:(NSString *)username error:(NSError **)outError;
- (SFTPRequest *)onConnect:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)attributesOfItemAtURL:(NSURL *)url
			    onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback;

- (SFTPRequest *)fileExistsAtURL:(NSURL *)url
		       onResponse:(void (^)(NSURL *, BOOL, NSError *))responseCallback;

- (SFTPRequest *)dataWithContentsOfURL:(NSURL *)url
				onData:(void (^)(NSData *))dataCallback
			    onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback;

- (SFTPRequest *)contentsOfDirectoryAtPath:(NSString *)path
				onResponse:(void (^)(NSArray *, NSError *))responseCallback;

- (SFTPRequest *)createDirectory:(NSString *)path
		      onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)renameItemAtPath:(NSString *)oldPath
			   toPath:(NSString *)newPath
		       onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)atomicallyRenameItemAtPath:(NSString *)oldPath
				     toPath:(NSString *)newPath
				 onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)removeItemAtPath:(NSString *)path
		       onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)writeDataSefely:(NSData *)data
			  toFile:(NSString *)path
		      onResponse:(void (^)(NSError *))responseCallback;

- (void)dequeueRequest:(uint32_t)requestId;
- (void)flushDirectoryCache;
- (NSString *)hostWithUser;
- (NSString *)stderr;
- (BOOL)hasPosixRename;
- (void)abort;
- (void)close;
- (BOOL)closed;
- (BOOL)connected;
- (NSURL *)normalizeURL:(NSURL *)aURL;

@end
