@interface TxmtURLProtocol : NSURLProtocol
{
	id<NSURLProtocolClient> _client;
}
+ (void)registerProtocol;
+ (NSURL *)parseURL:(NSURL *)url intoLineNumber:(NSNumber **)outLineNumber;
@end

