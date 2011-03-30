#import "ViMap.h"

@interface ViCommand : NSObject
{
	ViMapping *mapping;
	ViCommand *motion;
	ViCommand *operator;
	BOOL fromDot;
	BOOL isLineMode;
	int count;
	int saved_count;
	unichar argument;
	unichar reg;
	id text;
}

@property (readonly) ViMapping *mapping;
@property (readwrite) int count;
@property (readwrite) BOOL fromDot;
@property (readwrite) BOOL isLineMode;
@property (readonly) BOOL isMotion;
@property (readonly) BOOL hasOperator;
@property (readwrite) unichar argument;
@property (readwrite) unichar reg;
@property (readwrite) ViCommand *motion;
@property (readwrite) ViCommand *operator;
@property (readwrite) id text;

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
