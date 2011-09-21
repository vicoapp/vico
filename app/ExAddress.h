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
	enum ExAddressType	 _type;
	NSInteger		 _offset;
	NSInteger		 _line;
	NSString		*_pattern;
	BOOL			 _backwards;
	unichar			 _mark;
}

@property(nonatomic,readwrite) enum ExAddressType type;
@property(nonatomic,readwrite) NSInteger offset;
@property(nonatomic,readwrite) NSInteger line;
@property(nonatomic,readwrite,copy) NSString *pattern;
@property(nonatomic,readwrite) BOOL backwards;
@property(nonatomic,readwrite) unichar mark;

+ (ExAddress *)address;

@end
