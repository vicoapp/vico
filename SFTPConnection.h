#import <Cocoa/Cocoa.h>

#include <sys/stat.h>

#include "sftp.h"
#include "buffer.h"
#include "sftp-common.h"
#include "sftp-client.h"
#include "misc.h"

@interface SFTPDirectoryEntry : NSObject
{
	SFTP_DIRENT *dirent;
	NSString *filename;
	Attrib *attributes;
}
@property(readonly) NSString *filename;
@property(readonly) Attrib *attributes;
- (SFTPDirectoryEntry *)initWithPointer:(SFTP_DIRENT *)aDirent;
@end

@interface SFTPConnection : NSObject
{
	NSString *host;
	NSString *user;

	NSTask *ssh_task;
	NSPipe *ssh_input;
	NSPipe *ssh_output;
	NSPipe *ssh_error;
	int fd_in, fd_out;        // pipes to ssh process
	struct sftp_conn *conn;
	
	NSMutableData *stderr;
}

@property(readonly) NSString *host;
@property(readonly) NSString *user;

+ (NSError *)errorWithDescription:(id)errorDescription;

- (SFTPConnection *)initWithHost:(NSString *)hostname user:(NSString *)username error:(NSError **)outError;

- (Attrib *)stat:(NSString *)path error:(NSError **)outError;
- (BOOL)isDirectory:(NSString *)path;
- (NSArray *)directoryContentsAtPath:(NSString *)path error:(NSError **)outError;
- (NSString *)currentDirectory;
- (NSData *)dataWithContentsOfFile:(NSString *)path error:(NSError **)outError;
- (BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)outError;
- (NSString *)hostWithUser;
- (NSString *)stderr;

@end
