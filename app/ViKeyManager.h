#import "ViCommon.h"
#import "ViParser.h"
#import "ViScope.h"

@interface ViKeyManager : NSObject
{
	ViMode mode;
	ViParser *parser;
	id target;
	NSTimer *keyTimeout;
	NSInteger recursionLevel;
}

@property(nonatomic,readonly) ViParser *parser;
@property(nonatomic,readwrite,assign) id target;

- (ViKeyManager *)initWithTarget:(id)aTarget
                          parser:(ViParser *)aParser;
- (ViKeyManager *)initWithTarget:(id)aTarget
                      defaultMap:(ViMap *)map;

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent;
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent inScope:(ViScope *)scope;
- (void)keyDown:(NSEvent *)theEvent;
- (void)keyDown:(NSEvent *)theEvent inScope:(ViScope *)scope;
- (BOOL)handleKey:(NSInteger)keyCode;
- (BOOL)handleKey:(NSInteger)keyCode inScope:(ViScope *)scope;
- (void)handleKeys:(NSArray *)keys;
- (void)handleKeys:(NSArray *)keys inScope:(ViScope *)scope;
- (BOOL)runAsMacro:(NSString *)inputString interactively:(BOOL)interactiveFlag;
- (BOOL)runAsMacro:(NSString *)inputString;
@end

@interface NSObject (ViKeyManagerTarget)
- (BOOL)keyManager:(ViKeyManager *)aKeyManager
    shouldParseKey:(NSInteger)keyCode
	   inScope:(ViScope *)scope;
- (void)keyManager:(ViKeyManager *)aKeyManager
      presentError:(NSError *)error;
- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command;
- (void)keyManager:(ViKeyManager *)keyManager
  partialKeyString:(NSString *)keyString;
@end

