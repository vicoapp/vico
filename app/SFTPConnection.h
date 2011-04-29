#import "ViBufferedStream.h"
#import "ViURLManager.h"

#include <sys/stat.h>

/*
 * http://tools.ietf.org/html/draft-ietf-secsh-filexfer-13
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
}
@property (copy) void (^onResponse)(SFTPMessage *);
@property (copy) void (^onCancel)(SFTPRequest *);
@property (readwrite, assign) SFTPRequest *subRequest;
@property (readwrite) BOOL cancelled;
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

@interface SFTPConnection : NSObject <NSStreamDelegate>
{
	NSString *host;
	NSString *user;
	NSString *home;		/* home directory == current directory on connect */

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
- (BOOL)closed;

- (void)attributesOfItemAtPath:(NSString *)path
		    onResponse:(void (^)(NSDictionary *, NSError *))responseCallback;

- (void)fileExistsAtPath:(NSString *)path
	      onResponse:(void (^)(BOOL, BOOL, NSError *))responseCallback;

- (void)contentsOfDirectoryAtPath:(NSString *)path
		       onResponse:(void (^)(NSArray *, NSError *))responseCallback;

- (void)createDirectory:(NSString *)path
	     onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)dataWithContentsOfFile:(NSString *)path
				 onData:(void (^)(NSData *))dataCallback
			     onResponse:(void (^)(NSError *))responseCallback;

- (void)renameItemAtPath:(NSString *)oldPath
		  toPath:(NSString *)newPath
	      onResponse:(void (^)(NSError *))responseCallback;

- (void)removeItemAtPath:(NSString *)path
	      onResponse:(void (^)(NSError *))responseCallback;

- (void)dequeueRequest:(uint32_t)requestId;
- (void)flushDirectoryCache;
- (BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)outError;
- (NSString *)hostWithUser;
- (NSString *)stderr;
- (BOOL)hasPosixRename;
- (void)close;

@end
