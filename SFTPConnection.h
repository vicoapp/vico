#import <Cocoa/Cocoa.h>

#include <sys/stat.h>

#include "sftp.h"
#include "buffer.h"
#include "sftp-common.h"
#include "sftp-client.h"
#include "misc.h"

#define SSH_PATH "/usr/bin/ssh"

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
	NSString *target;         // "user@host" or just "host"
	int fd_in, fd_out;        // pipes to ssh process
	struct sftp_conn *conn;
	NSString *controlPath;

	/* PID of ssh transport process */
	pid_t sshpid;
}

@property(readonly) NSString *controlPath;
@property(readonly) NSString *target;

- (SFTPConnection *)initWithTarget:(NSString *)aTarget;
- (SFTPConnection *)initWithControlPath:(NSString *)aPath;

- (Attrib *)stat:(NSString *)path;
- (BOOL)isDirectory:(NSString *)path;
- (NSArray *)directoryContentsAtPath:(NSString *)path;
- (NSString *)currentDirectory;
- (NSData *)dataWithContentsOfFile:(NSString *)path;
- (BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)outError;

@end
