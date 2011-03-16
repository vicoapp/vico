#import "JSCocoa.h"

@interface ViScriptProxy : NSObject
{
	id _object;
	NSMutableDictionary *_listeners;
}

@property(readonly) id __obj;

- (ViScriptProxy *)initWithObject:(id)object;
- (void)emit:(NSString *)event with:(id)arg1, ...;
- (void)emit:(NSString *)event withArguments:(NSArray *)arguments;
- (void)emitDelayed:(NSString *)event withArguments:(NSArray *)arguments;
- (void)emitDelayed:(NSString *)event with:(id)arg1, ...;
- (void)onEvent:(NSString *)event runCallback:(JSValueRefAndContextRef)callbackFunction;
- (void)removeAllListeners:(NSString *)event;

@end
