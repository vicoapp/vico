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

#define ViStreamEventWriteEndEncountered 4711

@interface ViStreamBuffer : NSObject
{
	NSData		*_data;
	const void	*_ptr;
	NSUInteger	 _left;
	NSUInteger	 _length;
}

@property (nonatomic, readonly) const void *ptr;
@property (nonatomic, readonly) NSUInteger left;
@property (nonatomic, readonly) NSUInteger length;

- (ViStreamBuffer *)initWithBuffer:(const void *)buffer length:(NSUInteger)aLength;
- (ViStreamBuffer *)initWithData:(NSData *)aData;

@end




@interface ViBufferedStream : NSStream
{
	char			 _buffer[64*1024];
	ssize_t			 _buflen;

	id<NSStreamDelegate>	 _delegate;

	NSMutableArray		*_outputBuffers;

	int			 _fd_in, _fd_out;
	CFSocketRef		 _inputSocket, _outputSocket;
	CFRunLoopSourceRef	 _inputSource, _outputSource;
	CFSocketContext		 _inputContext, _outputContext;
}

@property (nonatomic,readwrite,assign) id<NSStreamDelegate> delegate;

+ (id)streamWithTask:(NSTask *)task;

- (id)initWithReadDescriptor:(int)read_fd
	     writeDescriptor:(int)write_fd
		    priority:(int)prio;
- (id)initWithTask:(NSTask *)task;
- (BOOL)bidirectional;

- (id)initWithNode:(NSString *)node
           service:(NSString *)service
              type:(int)socktype
            family:(int)family
          protocol:(int)proto
	     error:(NSError **)outError;
- (id)initWithHost:(NSString *)host port:(int)port;
+ (id)streamWithHost:(NSString *)host port:(int)port;
- (id)initWithLocalSocket:(NSString *)file;
+ (id)streamWithLocalSocket:(NSString *)file;

- (BOOL)hasBytesAvailable;
- (BOOL)hasSpaceAvailable;

- (void)shutdownWrite;
- (void)shutdownRead;

- (void)schedule;

- (BOOL)getBuffer:(const void **)buf length:(NSUInteger *)len;
- (NSData *)data;

- (void)write:(const void *)buf length:(NSUInteger)length;
- (void)writeData:(NSData *)data;
- (void)writeString:(NSString *)aString;

@end
