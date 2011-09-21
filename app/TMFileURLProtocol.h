@interface TMFileURLProtocol : NSURLProtocol
{
	id<NSURLProtocolClient> _client;
}
+ (void)registerProtocol;
@end

