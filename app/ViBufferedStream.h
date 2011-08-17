#define ViStreamEventWriteEndEncountered 4711

@interface ViStreamBuffer : NSObject
{
	NSData *data;
	const void *ptr;
	NSUInteger left;
	NSUInteger length;
}
@property (nonatomic, readonly) const void *ptr;
@property (nonatomic, readonly) NSUInteger left;
@property (nonatomic, readonly) NSUInteger length;
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
	CFRunLoopSourceRef	 inputSource, outputSource;
	CFSocketContext		 inputContext, outputContext;
}

- (id)initWithReadDescriptor:(int)read_fd
	     writeDescriptor:(int)write_fd
		    priority:(int)prio;
- (id)initWithTask:(NSTask *)task;
- (BOOL)bidirectional;

- (BOOL)hasBytesAvailable;
- (BOOL)hasSpaceAvailable;

- (void)shutdownWrite;
- (void)shutdownRead;

- (BOOL)getBuffer:(const void **)buf length:(NSUInteger *)len;
- (NSData *)data;

- (void)write:(const void *)buf length:(NSUInteger)length;
- (void)writeData:(NSData *)data;

@end
