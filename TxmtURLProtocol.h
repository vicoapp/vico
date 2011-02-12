@interface TxmtURLProtocol : NSURLProtocol
{
	id<NSURLProtocolClient> client;
}
+ (void)registerProtocol;
@end

