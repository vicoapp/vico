/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
	uint8_t		 _type;
	uint32_t	 _requestId;
	NSData		*_data;
	const void	*_ptr;
}

@property (nonatomic, readonly) uint8_t type;
@property (nonatomic, readonly) uint32_t requestId;
@property (nonatomic, readonly) NSData *data;

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


/* Dummy interface to fool XCode into letting us use the same nib for
 * different classes.
 * Is there a better way?
 */
@interface ViCancellableDummy : NSObject
{
	/* Blocking for completion. */
	IBOutlet NSWindow *waitWindow;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *waitLabel;
}
- (IBAction)cancelTask:(id)sender;
@end

@class SFTPConnection;


#pragma mark -


@interface SFTPRequest : NSObject <ViDeferred>
{
	uint32_t			 _requestId;
	uint32_t			 _requestType;
	SFTPConnection			*_connection;
	BOOL				 _cancelled;
	BOOL				 _finished;
	SFTPRequest			*_subRequest;
	CGFloat				 _progress;
	id<ViDeferredDelegate>		 _delegate;

	/* Blocking for completion. */
	IBOutlet NSWindow		*waitWindow;
	IBOutlet NSButton		*cancelButton;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSTextField		*waitLabel;
	SFTPRequest			*_waitRequest;

	void (^_responseCallback)(SFTPMessage *);
	void (^_cancelCallback)(SFTPRequest *);
}

@property (nonatomic, copy) void (^onResponse)(SFTPMessage *);
@property (nonatomic, copy) void (^onCancel)(SFTPRequest *);
@property (nonatomic, readwrite, strong) SFTPRequest *subRequest;
@property (nonatomic, readonly) BOOL cancelled;
@property (nonatomic, readwrite) CGFloat progress;
@property (nonatomic, readonly) uint32_t requestId;
@property (nonatomic, readwrite, strong) SFTPRequest *waitRequest;

+ (SFTPRequest *)requestWithId:(uint32_t)reqId
			ofType:(uint32_t)type
		  onConnection:(SFTPConnection *)aConnection;
- (SFTPRequest *)initWithId:(uint32_t)reqId
		     ofType:(uint32_t)type
	       onConnection:(SFTPConnection *)aConnection;

- (void)response:(SFTPMessage *)msg;
- (IBAction)cancelTask:(id)sender;

@end


#pragma mark -


@interface SFTPConnection : NSObject <NSStreamDelegate>
{
	NSString		*_host;
	NSString		*_user;
	NSNumber		*_port;
	NSString		*_home;		/* home directory == current directory on connect */

	id			 _delegate;

	NSTask			*_ssh_task;

	int			 _remoteVersion;

	/* Outstanding requests, keyed on request ID. */
	NSMutableDictionary	*_requests;
	/* The initial INIT request does not have a request ID. */
	SFTPRequest		*_initRequest;

	NSMutableData		*_inbuf;
	NSMutableData		*_errbuf;

	ViBufferedStream	*_sshPipe;
	ViBufferedStream	*_errStream;

	uint32_t		 _nextRequestId;
	uint32_t		 _transfer_buflen;

#define SFTP_EXT_POSIX_RENAME	 0x00000001
#define SFTP_EXT_STATVFS	 0x00000002
#define SFTP_EXT_FSTATVFS	 0x00000004
	uint32_t		 _exts;
}

@property(nonatomic,readonly) NSString *host;
@property(nonatomic,readonly) NSString *user;
@property(nonatomic,readwrite,strong) NSString *home;
@property(weak, nonatomic,readonly) NSString *title;

- (SFTPConnection *)initWithURL:(NSURL *)url error:(NSError **)outError;
- (SFTPRequest *)onConnect:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)attributesOfItemAtURL:(NSURL *)url
			    onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback;

- (SFTPRequest *)fileExistsAtURL:(NSURL *)url
		       onResponse:(void (^)(NSURL *, BOOL, NSError *))responseCallback;

- (SFTPRequest *)dataWithContentsOfURL:(NSURL *)url
				onData:(void (^)(NSData *))dataCallback
			    onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback;

- (SFTPRequest *)contentsOfDirectoryAtURL:(NSURL *)aURL
				onResponse:(void (^)(NSArray *, NSError *))responseCallback;

- (SFTPRequest *)createDirectory:(NSString *)path
		      onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)moveItemAtURL:(NSURL *)srcURL
			 toURL:(NSURL *)dstURL
		    onResponse:(void (^)(NSURL *, NSError *))responseCallback;

- (SFTPRequest *)renameItemAtPath:(NSString *)oldPath
			   toPath:(NSString *)newPath
		       onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)atomicallyRenameItemAtPath:(NSString *)oldPath
				     toPath:(NSString *)newPath
				 onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)removeItemAtPath:(NSString *)path
		       onResponse:(void (^)(NSError *))responseCallback;
- (SFTPRequest *)removeItemsAtURLs:(NSArray *)urls
		       onResponse:(void (^)(NSError *))responseCallback;

- (SFTPRequest *)writeDataSafely:(NSData *)data
			  toURL:(NSURL *)aURL
		      onResponse:(void (^)(NSURL *, NSDictionary *, NSError *))responseCallback;

- (void)dequeueRequest:(uint32_t)requestId;
- (NSString *)stderr;
- (BOOL)hasPosixRename;
- (void)abort;
- (void)close;
- (BOOL)closed;
- (BOOL)connected;
- (NSURL *)normalizeURL:(NSURL *)aURL;
- (NSString *)stringByAbbreviatingWithTildeInPath:(NSURL *)aURL;

@end
