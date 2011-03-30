#import "ViKeyManager.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#include "logging.h"

@implementation ViKeyManager

- (ViKeyManager *)initWithTarget:(id)aTarget
                      defaultMap:(ViMap *)map
{
	if ((self = [super init]) != nil) {
		parser = [[ViParser alloc] initWithDefaultMap:map];
		target = aTarget;
	}
	return self;
}

- (void)presentViError:(NSError *)error
{
	if ([target respondsToSelector:@selector(presentViError:)])
		[target performSelector:@selector(presentViError:) withObject:error];
}

- (BOOL)handleKey:(NSInteger)keyCode error:(NSError **)outError
{
	[keyTimeout invalidate];

	if (keyCode == -1) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Internal error."];
		return NO;
	}

	NSError *error = nil;
	BOOL timeout = NO;
	ViCommand *command = [parser pushKey:keyCode
				       scope:nil
				     timeout:&timeout
				       error:&error];
	if (command) {
		if ([target respondsToSelector:@selector(keyManager:evaluateCommand:)])
			[target performSelector:@selector(keyManager:evaluateCommand:)
				     withObject:self
				     withObject:command];
	} else if (error) {
		if (outError)
			*outError = error;
		return NO;
	} else {
		if ([target respondsToSelector:@selector(keyManager:partialKeyString:)])
			[target performSelector:@selector(keyManager:partialKeyString:)
				     withObject:self
				     withObject:parser.keyString];
		if (timeout)
			keyTimeout = [NSTimer scheduledTimerWithTimeInterval:1.0
								       target:self
								     selector:@selector(keyTimedOut:)
								     userInfo:self
								      repeats:NO];
	}

	return YES;
}

- (void)handleKey:(NSInteger)keyCode
{
	NSError *error = nil;
	if (![self handleKey:keyCode error:&error] && error)
		[self presentViError:error];
}

- (void)keyTimedOut:(id)sender
{
	NSError *error = nil;
	ViCommand *command = [parser timeoutInScope:nil error:&error];
	if (command) {
		if ([target respondsToSelector:@selector(keyManager:evaluateCommand:)])
			[target performSelector:@selector(keyManager:evaluateCommand:)
				     withObject:self
				     withObject:command];
	} else if (error)
		[self presentViError:error];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	BOOL partial = parser.partial;
	NSError *error = nil;
	if (![self handleKey:[theEvent normalizedKeyCode] error:&error]) {
		if (!partial && [error code] == ViErrorMapNotFound)
			return NO;
		[self presentViError:error];
	}

	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	[self handleKey:[theEvent normalizedKeyCode]];
}

@end
