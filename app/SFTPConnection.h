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

@interface SFTPConnection : NSObject
{
	NSString *host;
	NSString *user;
	NSString *home;		/* home directory == current directory on connect */

	NSTask *ssh_task;
	NSPipe *ssh_input;
	NSPipe *ssh_output;
	NSPipe *ssh_error;
	int fd_in, fd_out;        // pipes to ssh process

	u_int transfer_buflen;
	u_int version;
	u_int msg_id;
#define SFTP_EXT_POSIX_RENAME	0x00000001
#define SFTP_EXT_STATVFS	0x00000002
#define SFTP_EXT_FSTATVFS	0x00000004
	u_int exts;
	
	NSMutableData *stderr;
	NSMutableDictionary *directoryCache;
}

@property(readonly) NSString *host;
@property(readonly) NSString *user;
@property(readonly) NSString *home;

- (SFTPConnection *)initWithHost:(NSString *)hostname user:(NSString *)username error:(NSError **)outError;
- (BOOL)closed;
- (BOOL)initConnectionError:(NSError **)outError;
- (Attrib *)stat:(NSString *)path error:(NSError **)outError;
- (BOOL)isDirectory:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory error:(NSError **)outError;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)createDirectory:(NSString *)path error:(NSError **)outError;
- (void)flushDirectoryCache;
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)outError;
- (NSString *)realpath:(NSString *)pathS error:(NSError **)outError;
- (NSString *)currentDirectory;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)outError;
- (BOOL)renameItemAtPath:(NSString *)oldPath toPath:(NSString *)newPath error:(NSError **)outError;
- (NSData *)dataWithContentsOfFile:(NSString *)path error:(NSError **)outError;
- (BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)outError;
- (NSString *)hostWithUser;
- (NSString *)stderr;
- (BOOL)hasPosixRename;

@end
