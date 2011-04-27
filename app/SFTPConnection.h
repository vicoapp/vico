#import "ViBufferedStream.h"

#include <sys/stat.h>

#include "sftp.h"
#include "buffer.h"
#include "sftp-common.h"
#include "sftp-client.h"
#include "misc.h"

@interface SFTPDirectoryEntry : NSObject
{
	NSString *filename;
	Attrib attributes;
}
@property(readonly) NSString *filename;
@property(readonly) Attrib *attributes;
- (SFTPDirectoryEntry *)initWithFilename:(const char *)afilename attributes:(Attrib *)a;
- (BOOL)isDirectory;
@end

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

@interface SFTPRequest : NSObject
{
	uint32_t requestId;
	void (^responseCallback)(SFTPMessage *);
}
+ (SFTPRequest *)requestWithId:(uint32_t)reqId onResponse:(void (^)(SFTPMessage *))aCallback;
- (SFTPRequest *)initWithId:(uint32_t)reqId onResponse:(void (^)(SFTPMessage *))aCallback;
- (void)response:(SFTPMessage *)msg;
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
	//int fd_in, fd_out;        // pipes to ssh process

	int remoteVersion;

	/* Outstanding requests, keyed on request ID. */
	NSMutableDictionary *requests;
	SFTPRequest *initRequest;

	NSMutableData *inbuf;
	NSMutableData *errbuf;

	ViBufferedStream *sshPipe;

	uint32_t nextRequestId;

	u_int transfer_buflen;
	u_int version;
	u_int msg_id;
#define SFTP_EXT_POSIX_RENAME	0x00000001
#define SFTP_EXT_STATVFS	0x00000002
#define SFTP_EXT_FSTATVFS	0x00000004
	u_int exts;
	
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

- (void)dataWithContentsOfFile:(NSString *)path
		    onResponse:(void (^)(NSData *, NSError *))responseCallback;

- (void)flushDirectoryCache;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)outError;
- (BOOL)renameItemAtPath:(NSString *)oldPath toPath:(NSString *)newPath error:(NSError **)outError;
- (BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)outError;
- (NSString *)hostWithUser;
- (NSString *)stderr;
- (BOOL)hasPosixRename;
- (void)close;

@end
