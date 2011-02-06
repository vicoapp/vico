@interface TMFileURLProtocol : NSURLProtocol
{
	id<NSURLProtocolClient> client;
}
+ (void)registerProtocol;
@end

