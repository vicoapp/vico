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

- (BOOL)hasBytesAvailable;
- (BOOL)hasSpaceAvailable;

- (void)shutdownWrite;
- (void)shutdownRead;

- (BOOL)getBuffer:(const void **)buf length:(NSUInteger *)len;
- (NSData *)data;

- (void)write:(const void *)buf length:(NSUInteger)length;
- (void)writeData:(NSData *)data;

@end
