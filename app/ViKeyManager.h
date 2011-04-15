#import "ViCommon.h"
#import "ViParser.h"

@interface ViKeyManager : NSObject
{
	ViMode mode;
	ViParser *parser;
	id target;
	NSTimer *keyTimeout;
	NSInteger recursionLevel;
}

@property (readonly) ViParser *parser;

- (ViKeyManager *)initWithTarget:(id)aTarget
                          parser:(ViParser *)aParser;
- (ViKeyManager *)initWithTarget:(id)aTarget
                      defaultMap:(ViMap *)map;

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent;
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent inScope:(NSArray *)scopeArray;
- (void)keyDown:(NSEvent *)theEvent;
- (void)keyDown:(NSEvent *)theEvent inScope:(NSArray *)scopeArray;
- (BOOL)handleKey:(NSInteger)keyCode;
- (BOOL)handleKey:(NSInteger)keyCode inScope:(NSArray *)scopeArray;
- (void)handleKeys:(NSArray *)keys;
- (void)handleKeys:(NSArray *)keys inScope:(NSArray *)scopeArray;
- (void)runAsMacro:(NSString *)inputString;
@end

@interface NSObject (ViKeyManagerTarget)
- (BOOL)keyManager:(ViKeyManager *)aKeyManager
    shouldParseKey:(NSInteger)keyCode;
- (void)keyManager:(ViKeyManager *)aKeyManager
      presentError:(NSError *)error;
- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command;
- (void)keyManager:(ViKeyManager *)keyManager
  partialKeyString:(NSString *)keyString;
@end

