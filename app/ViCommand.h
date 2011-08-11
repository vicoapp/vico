#import "ViMap.h"
#import "ViMacro.h"

/** A generated vi command.
 */
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
	NSRange range;
	NSInteger caret;
}

/** The mapping that describes the action. */
@property(nonatomic,readonly) ViMapping *mapping;

/** Any count given to the command. */
@property(nonatomic,readwrite) int count;

@property(nonatomic,readwrite) int saved_count;
@property(nonatomic,readwrite) BOOL fromDot;

/** YES if the mapped action operates on whole lines. */
@property(nonatomic,readwrite) BOOL isLineMode;

/** YES if the mapped action is a motion command. */
@property(nonatomic,readonly) BOOL isMotion;

/** YES if the mapped action is a motion component for an operator. */
@property(nonatomic,readonly) BOOL hasOperator;

/** The argument, if any. Only applicable if the mapping specified the ViMapNeedArgument flag. */
@property(nonatomic,readwrite) unichar argument;

/** The register, if any. */
@property(nonatomic,readwrite) unichar reg;

/** The motion command, if this command is an operator action. */
@property(nonatomic,readwrite) ViCommand *motion;

/** The operator command, if this command is a motion component. */
@property(nonatomic,readwrite) ViCommand *operator;

@property(nonatomic,readwrite) id text;

@property(nonatomic,readwrite) NSRange range;
@property(nonatomic,readwrite) NSInteger caret;

@property(nonatomic,readwrite) ViMacro *macro;

+ (ViCommand *)commandWithMapping:(ViMapping *)aMapping
                            count:(int)aCount;
- (ViCommand *)initWithMapping:(ViMapping *)aMapping
                         count:(int)aCount;

- (SEL)action;
- (BOOL)isUndo;
- (BOOL)isDot;
- (ViCommand *)dotCopy;

@end
