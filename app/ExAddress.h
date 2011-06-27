enum ExAddressType {
	ExAddressNone,
	ExAddressAbsolute,
	ExAddressSearch,
	ExAddressMark,
	ExAddressCurrent,
	ExAddressRelative
};

@interface ExAddress : NSObject <NSCopying>
{
	enum ExAddressType type;
	NSInteger offset;
	NSInteger line;
	NSString *pattern;
	BOOL backwards;
	unichar mark;
}

@property(nonatomic,readwrite,assign) enum ExAddressType type;
@property(nonatomic,readwrite,assign) NSInteger offset;
@property(nonatomic,readwrite,assign) NSInteger line;
@property(nonatomic,readwrite,assign) NSString *pattern;
@property(nonatomic,readwrite,assign) BOOL backwards;
@property(nonatomic,readwrite,assign) unichar mark;

@end
