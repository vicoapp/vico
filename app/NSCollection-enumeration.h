#define ENUMERATION_INTERFACE_FOR(CLASS_NAME) @interface CLASS_NAME (enumeration)\
\
- (void)eachBlock:(void (^)(id obj, BOOL *stop))block; \
- (NSSet *)mapBlock:(id (^)(id obj, BOOL *stop))block; \
\
@end

ENUMERATION_INTERFACE_FOR(NSSet)
ENUMERATION_INTERFACE_FOR(NSArray)
