@implementation NSWindow (additions)

- (BOOL)isFullScreen
{
	return ([self styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask;
}

- (id)firstResponderOrDelegate
{
	id resp = [self firstResponder];
	if ([resp isKindOfClass:[NSTextView class]] && resp == [self fieldEditor:NO forObject:nil])
		resp = [(NSTextView *)resp delegate];
	return resp;
}

@end
