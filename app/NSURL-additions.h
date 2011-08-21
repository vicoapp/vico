@interface NSURL (equality)
- (BOOL)isEqualToURL:(NSURL *)otherURL;
- (BOOL)hasPrefix:(NSURL *)prefixURL;
- (NSURL *)URLWithRelativeString:(NSString *)string;
@end
