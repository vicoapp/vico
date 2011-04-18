@interface TxmtURLProtocol : NSURLProtocol
{
	id<NSURLProtocolClient> client;
}
+ (void)registerProtocol;
+ (NSURL *)parseURL:(NSURL *)url intoLineNumber:(NSNumber **)outLineNumber;
@end

