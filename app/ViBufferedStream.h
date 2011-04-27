@interface ViStreamBuffer : NSObject
{
	NSData *data;
	const void *ptr;
	NSUInteger left;
	NSUInteger length;
}
@property (readonly) const void *ptr;
@property (readonly) NSUInteger left;
@property (readonly) NSUInteger length;
- (ViStreamBuffer *)initWithBuffer:(const void *)buffer length:(NSUInteger)aLength;
- (ViStreamBuffer *)initWithData:(NSData *)aData;
@end

@interface ViBufferedStream : NSStream
{
	char			 buffer[64*1024];
	ssize_t			 buflen;

	id<NSStreamDelegate>	 delegate;

	NSMutableArray		*outputBuffers;

	int			 fd_in, fd_out;
	CFSocketRef		 inputSocket, outputSocket;
	CFRunLoopSourceRef	 inputSource , outputSource;
	CFSocketContext		 inputContext, outputContext;

	NSRunLoop		*runLoop;
	NSString		*runLoopMode;
}

- (id)initWithReadFileDescriptor:(int)read_fd
	     writeFileDescriptor:(int)write_fd;
- (id)initWithTask:(NSTask *)task;

- (BOOL)hasBytesAvailable;
- (BOOL)hasSpaceAvailable;

- (void)shutdownWrite;
- (void)shutdownRead;

- (BOOL)getBuffer:(const void **)buf length:(NSUInteger *)len;

- (void)write:(const void *)buf length:(NSUInteger)length;
- (void)writeData:(NSData *)data;

@end
