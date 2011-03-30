#import "ViCommon.h"
#import "ViParser.h"

@interface ViKeyManager : NSObject
{
	ViMode mode;
	ViParser *parser;
	id target;
	NSTimer *keyTimeout;
}

- (ViKeyManager *)initWithTarget:(id)aTarget
                      defaultMap:(ViMap *)map;

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent;
- (void)keyDown:(NSEvent *)theEvent;
@end

@interface NSObject (ViKeyManagerTarget)
- (void)presentViError:(NSError *)error;
- (void)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command;
- (void)keyManager:(ViKeyManager *)keyManager
  partialKeyString:(NSString *)keyString;
@end
