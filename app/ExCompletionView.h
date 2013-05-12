#import "NSView-additions.h"

#import "ViKeyManager.h"
#import "ViMap.h"

@interface ExCompletionView : NSTableView <ViKeyManagerTarget>
{
	ViKeyManager *_keyManager;
	ViMap *_completionMap;
}

- (void)keyDown:(NSEvent *)event;
- (BOOL)performKeyEquivalent:(NSEvent *)event;
- (BOOL)keyManager:(ViKeyManager *)keyManager evaluateCommand:(ViCommand *)command;

@end
