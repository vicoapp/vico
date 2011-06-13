#import "ViMap.h"
#import "ViMacro.h"

@interface ViCommand : NSObject
{
	ViMapping *mapping;
	ViCommand *motion;
	ViCommand *operator;
	ViMacro *macro;
	BOOL fromDot;
	BOOL isLineMode;
	int count;
	int saved_count;
	unichar argument;
	unichar reg;
	id text;
	NSRange affectedRange;
	NSUInteger finalLocation;
}

@property(nonatomic,readonly) ViMapping *mapping;
@property(nonatomic,readwrite) int count;
@property(nonatomic,readwrite) BOOL fromDot;
@property(nonatomic,readwrite) BOOL isLineMode;
@property(nonatomic,readonly) BOOL isMotion;
@property(nonatomic,readonly) BOOL hasOperator;
@property(nonatomic,readwrite) unichar argument;
@property(nonatomic,readwrite) unichar reg;
@property(nonatomic,readwrite) ViCommand *motion;
@property(nonatomic,readwrite) ViCommand *operator;
@property(nonatomic,readwrite) id text;
@property(nonatomic,readwrite) NSRange affectedRange;
@property(nonatomic,readwrite) NSUInteger finalLocation;
@property(nonatomic,readwrite) ViMacro *macro;

+ (ViCommand *)commandWithMapping:(ViMapping *)aMapping
                            count:(int)aCount;
- (ViCommand *)initWithMapping:(ViMapping *)aMapping
                         count:(int)aCount;

- (SEL)action;
- (BOOL)isMotion;
- (BOOL)isUndo;
- (BOOL)isDot;
- (BOOL)hasOperator;
- (ViCommand *)dotCopy;

@end
