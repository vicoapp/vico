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

#include <sys/uio.h>
#include <unistd.h>
#include <vis.h>

#import "ViBufferedStream.h"
#include "logging.h"

@implementation ViStreamBuffer

@synthesize ptr = _ptr;
@synthesize left = _left;
@synthesize length = _length;

- (ViStreamBuffer *)initWithData:(NSData *)aData
{
	if ((self = [super init]) != nil) {
		_data = [aData retain];
		_ptr = [_data bytes];
		_length = _left = [_data length];
	}
	DEBUG_INIT();
	return self;
}

- (ViStreamBuffer *)initWithBuffer:(const void *)buffer length:(NSUInteger)aLength
{
	if ((self = [super init]) != nil) {
		_ptr = buffer;
		_length = _left = aLength;
	}
	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_data release];
	[super dealloc];
}

- (void)setConsumed:(NSUInteger)size
{
	_ptr += size;
	_left -= size;
	DEBUG(@"consumed %lu bytes of buffer, %lu bytes left", size, _left);
}

@end


#pragma mark -


@implementation ViBufferedStream

@synthesize delegate = _delegate;

- (void)dealloc
{
	DEBUG_DEALLOC();
	[self close];
	[_outputBuffers release];
	[super dealloc];
}

- (void)read
{
	DEBUG(@"reading on fd %d", _fd_in);

	_buflen = 0;
	ssize_t ret = read(_fd_in, _buffer, sizeof(_buffer));
	if (ret <= 0) {
		if (ret == 0) {
			DEBUG(@"read EOF from fd %d", _fd_in);
			if ([_delegate respondsToSelector:@selector(stream:handleEvent:)]) {
				[_delegate stream:self handleEvent:NSStreamEventEndEncountered];
			}
		} else {
			DEBUG(@"read(%d) failed: %s", _fd_in, strerror(errno));
			if ([_delegate respondsToSelector:@selector(stream:handleEvent:)]) {
				[_delegate stream:self handleEvent:NSStreamEventErrorOccurred];
			}
		}
		[self shutdownRead];
	} else {
		DEBUG(@"read %zi bytes from fd %i", ret, _fd_in);
#ifndef NO_DEBUG
		char *vis = malloc(ret*4+1);
		strvisx(vis, _buffer, ret, VIS_WHITE);
		DEBUG(@"read data: %s", vis);
		free(vis);
#endif
		_buflen = ret;
		if ([_delegate respondsToSelector:@selector(stream:handleEvent:)]) {
			[_delegate stream:self handleEvent:NSStreamEventHasBytesAvailable];
		}
	}
}

- (void)drain:(NSUInteger)size
{
	ViStreamBuffer *buf;

	DEBUG(@"draining %lu bytes", size);

	while (size > 0 && (buf = [_outputBuffers objectAtIndex:0]) != nil) {
		if (size >= buf.length) {
			size -= buf.length;
			[_outputBuffers removeObjectAtIndex:0];
		} else {
			[buf setConsumed:size];
			break;
		}
	}
}

- (int)flush
{
	struct iovec	 iov[IOV_MAX];
	unsigned int	 i = 0;
	ssize_t		 n;
	NSUInteger tot = 0;

	for (ViStreamBuffer *buf in _outputBuffers) {
		if (i >= IOV_MAX) {
			break;
		}
		iov[i].iov_base = (void *)buf.ptr;
		iov[i].iov_len = buf.left;
		tot += buf.left;
		i++;
	}

	if (tot == 0) {
		return 0;
	}

	DEBUG(@"flushing %i buffers, total %lu bytes", i, tot);

	if ((n = writev(_fd_out, iov, i)) == -1) {
		int saved_errno = errno;
		DEBUG(@"writev failed with errno %s (%i, %i?)", strerror(saved_errno), saved_errno, EPIPE);
		if (saved_errno == EAGAIN || saved_errno == ENOBUFS ||
		    saved_errno == EINTR) {	/* try later */
			return 0;
		} else if (saved_errno == EPIPE) {
			/* treat a broken pipe as connection closed; we might still have stuff to read */
			return -2;
		} else {
			return -1;
		}
	}

	DEBUG(@"writev(%d) returned %zi", _fd_out, n);

	if (n == 0) {			/* connection closed */
		errno = 0;
		return -2;
	}

	[self drain:n];

	if ([_outputBuffers count] == 0) {
		return 0;
	}

	CFSocketCallBackType cbType = kCFSocketWriteCallBack;
	if (_outputSocket == _inputSocket) {
		cbType |= kCFSocketReadCallBack;
	}
	CFSocketEnableCallBacks(_outputSocket, cbType);
	return 1;
}

- (void)write
{
	int ret = [self flush];
	if (ret == 0) { /* all output buffers flushed to socket */
		if ([_delegate respondsToSelector:@selector(stream:handleEvent:)]) {
			[_delegate stream:self handleEvent:NSStreamEventHasSpaceAvailable];
		}
	} else if (ret == -1) {
		if ([_delegate respondsToSelector:@selector(stream:handleEvent:)]) {
			[_delegate stream:self handleEvent:NSStreamEventErrorOccurred];
		}
		[self shutdownWrite];
	} else if (ret == -2) {
		if ([_delegate respondsToSelector:@selector(stream:handleEvent:)]) {
			/*
			 * We got a broken pipe on the write stream. If we have different sockets
			 * for read and write, generate a special write-end event, otherwise we
			 * use a regular EOF event. The write-end event allows us to keep reading
			 * data buffered in the socket (ie, not yet received by the application).
			 *
			 * The usecase is when filtering through a non-filter like 'ls'.
			 */
			if ([self bidirectional]) {
				[_delegate stream:self handleEvent:NSStreamEventEndEncountered];
			} else {
				[_delegate stream:self handleEvent:ViStreamEventWriteEndEncountered];
			}
		}
		[self shutdownWrite];
	}
}

static void
fd_write(CFSocketRef s,
	 CFSocketCallBackType callbackType,
	 CFDataRef address,
	 const void *data,
	 void *info)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ViBufferedStream *stream = [[(ViBufferedStream *)info retain] autorelease];
	[stream write];
	[pool release];
}

static void
fd_read(CFSocketRef s,
	CFSocketCallBackType callbackType,
	CFDataRef address,
	const void *data,
	void *info)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ViBufferedStream *stream = [[(ViBufferedStream *)info retain] autorelease];
	switch (callbackType) {
	case kCFSocketReadCallBack:
		[stream read];
		break;
	case kCFSocketWriteCallBack:
		[stream write];
		break;
	}
	[pool release];
}

/* Returns YES if one bidirectional socket is in use, NO if two unidirectional sockets (a pipe pair) is used. */
- (BOOL)bidirectional
{
	return (_inputSocket == _outputSocket);
}

- (id)initWithReadDescriptor:(int)read_fd
	     writeDescriptor:(int)write_fd
		    priority:(int)prio
{
	DEBUG(@"init with read fd %d, write fd %d", read_fd, write_fd);

	if ((self = [super init]) != nil) {
		_fd_in = read_fd;
		_fd_out = write_fd;

		_outputBuffers = [[NSMutableArray alloc] init];

		int flags;
		if (_fd_in != -1) {
			if ((flags = fcntl(_fd_in, F_GETFL, 0)) == -1) {
				INFO(@"fcntl(%i, F_GETFL): %s", _fd_in, strerror(errno));
				return nil;
			}
			if (fcntl(_fd_in, F_SETFL, flags | O_NONBLOCK) == -1) {
				INFO(@"fcntl(%i, F_SETFL): %s", _fd_in, strerror(errno));
				return nil;
			}

			bzero(&_inputContext, sizeof(_inputContext));
			_inputContext.info = self; /* user data passed to the callbacks */

			CFSocketCallBackType cbType = kCFSocketReadCallBack;
			if (_fd_out == _fd_in) {
				/* bidirectional socket, we read and write on the same socket */
				cbType |= kCFSocketWriteCallBack;
			}
			_inputSocket = CFSocketCreateWithNative(
				kCFAllocatorDefault,
				_fd_in,
				cbType,
				fd_read,
				&_inputContext);
			if (_inputSocket == NULL) {
				INFO(@"failed to create input CFSocket of fd %i", _fd_in);
				return nil;
			}
			CFSocketSetSocketFlags(_inputSocket, kCFSocketAutomaticallyReenableReadCallBack);
			_inputSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _inputSocket, prio);

			CFSocketEnableCallBacks(_inputSocket, kCFSocketReadCallBack);
		}

		if (_fd_out != -1) {
			if (_fd_out == _fd_in) {
				/* bidirectional socket */
				_outputSocket = _inputSocket;
			} else {
				/* unidirectional socket, we read and write on different sockets */
				if ((flags = fcntl(_fd_out, F_GETFL, 0)) == -1) {
					INFO(@"fcntl(%i, F_GETFL): %s", _fd_out, strerror(errno));
					return nil;
				}
				if (fcntl(_fd_out, F_SETFL, flags | O_NONBLOCK) == -1) {
					INFO(@"fcntl(%i, F_SETFL): %s", _fd_out, strerror(errno));
					return nil;
				}

				bzero(&_outputContext, sizeof(_outputContext));
				_outputContext.info = self; /* user data passed to the callbacks */

				_outputSocket = CFSocketCreateWithNative(
					kCFAllocatorDefault,
					_fd_out,
					kCFSocketWriteCallBack,
					fd_write,
					&_outputContext);
				if (_outputSocket == NULL) {
					INFO(@"failed to create output CFSocket of fd %i", _fd_out);
					return nil;
				}
				CFSocketSetSocketFlags(_outputSocket, 0);
				_outputSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _outputSocket, prio);
			}
		}
	}
	DEBUG_INIT();
	return self;
}

+ (id)streamWithTask:(NSTask *)task
{
	return [[[ViBufferedStream alloc] initWithTask:task] autorelease];
}

- (id)initWithTask:(NSTask *)task
{
	id stdout = [task standardOutput];
	int fdin, fdout;
	if ([stdout isKindOfClass:[NSPipe class]]) {
		fdin = [[stdout fileHandleForReading] fileDescriptor];
	} else if ([stdout isKindOfClass:[NSFileHandle class]]) {
		fdin = [stdout fileDescriptor];
	} else {
		return nil;
	}

	id stdin = [task standardInput];
	if ([stdin isKindOfClass:[NSPipe class]]) {
		fdout = [[stdin fileHandleForWriting] fileDescriptor];
	} else if ([stdin isKindOfClass:[NSFileHandle class]]) {
		fdout = [stdin fileDescriptor];
	} else {
		return nil;
	}

	return [self initWithReadDescriptor:fdin
			    writeDescriptor:fdout
				   priority:5];
}

- (void)open
{
	INFO(@"%s", "open?");
}

- (void)shutdownWrite
{
	if (_outputSource) {
		DEBUG(@"shutting down write pipe %d", _fd_out);
		if ([_outputBuffers count] > 0) {
			INFO(@"fd %i has %lu non-flushed buffers pending", _fd_out, [_outputBuffers count]);
		}
		CFSocketInvalidate(_outputSocket); /* also removes the source from run loops */
		CFRelease(_outputSocket);
		CFRelease(_outputSource);
		_outputSocket = NULL;
		_outputSource = NULL;
		_fd_out = -1;
	}
	/*
	 * If _outputSource is NULL, we either have already closed the write socket,
	 * or we have a bidirectional socket. XXX: should we call shutdown(2) if
	 * full-duplex bidirectional socket?
	 */
}

- (void)shutdownRead
{
	if (_inputSource) {
		DEBUG(@"shutting down read pipe %d", _fd_in);
		CFSocketInvalidate(_inputSocket); /* also removes the source from run loops */
		if (_outputSocket == _inputSocket) {
			/*
                         * XXX: this also shuts down the write part for
                         * full-duplex bidirectional sockets.
			 */
			_outputSocket = NULL;
			_fd_out = -1;
		}
		CFRelease(_inputSocket);
		CFRelease(_inputSource);
		_inputSocket = NULL;
		_inputSource = NULL;
		_fd_in = -1;
	}
}

- (void)close
{
	[self shutdownRead];
	[self shutdownWrite];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
	DEBUG(@"adding to mode %@", mode);
	if (_inputSource)
		CFRunLoopAddSource([aRunLoop getCFRunLoop], _inputSource, (CFStringRef)mode);
	if (_outputSource)
		CFRunLoopAddSource([aRunLoop getCFRunLoop], _outputSource, (CFStringRef)mode);
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode
{
	DEBUG(@"removing from mode %@", mode);
	if (_inputSource)
		CFRunLoopRemoveSource([aRunLoop getCFRunLoop], _inputSource, (CFStringRef)mode);
	if (_outputSource)
		CFRunLoopRemoveSource([aRunLoop getCFRunLoop], _outputSource, (CFStringRef)mode);
}

- (BOOL)getBuffer:(const void **)buf length:(NSUInteger *)len
{
	*buf = _buffer;
	*len = _buflen;
	return YES;
}

- (NSData *)data
{
	return [NSData dataWithBytes:_buffer length:_buflen];
}

- (BOOL)hasBytesAvailable
{
	return _buflen > 0;
}

- (BOOL)hasSpaceAvailable
{
	return YES;
}

- (void)write:(const void *)buf length:(NSUInteger)length
{
	if (_outputSocket && length > 0) {
		DEBUG(@"enqueueing %lu bytes on fd %i", length, CFSocketGetNative(_outputSocket));
		[_outputBuffers addObject:[[[ViStreamBuffer alloc] initWithBuffer:buf length:length] autorelease]];

		CFSocketCallBackType cbType = kCFSocketWriteCallBack;
		if (_outputSocket == _inputSocket)
			cbType |= kCFSocketReadCallBack;
		CFSocketEnableCallBacks(_outputSocket, cbType);
	}
}

- (void)writeData:(NSData *)aData
{
	if (_outputSocket && [aData length] > 0) {
		DEBUG(@"enqueueing %lu bytes on fd %i", [aData length], CFSocketGetNative(_outputSocket));
		[_outputBuffers addObject:[[[ViStreamBuffer alloc] initWithData:aData] autorelease]];

		CFSocketCallBackType cbType = kCFSocketWriteCallBack;
		if (_outputSocket == _inputSocket)
			cbType |= kCFSocketReadCallBack;
		CFSocketEnableCallBacks(_outputSocket, cbType);
	}
}

- (id)propertyForKey:(NSString *)key
{
	DEBUG(@"key is %@", key);
	return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key
{
	DEBUG(@"key is %@", key);
	return NO;
}

- (NSStreamStatus)streamStatus
{
	DEBUG(@"returning %d", NSStreamStatusOpen);
	return NSStreamStatusOpen;
}

- (NSError *)streamError
{
	DEBUG(@"%s", "returning nil");
	return nil;
}

@end
