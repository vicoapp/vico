#import "ViKeyManager.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#include "logging.h"

@implementation ViKeyManager

@synthesize parser;

- (ViKeyManager *)initWithTarget:(id)aTarget
                          parser:(ViParser *)aParser
{
	if ((self = [super init]) != nil) {
		parser = aParser;
		target = aTarget;
	}
	return self;
}

- (ViKeyManager *)initWithTarget:(id)aTarget
                      defaultMap:(ViMap *)map
{
	return [self initWithTarget:aTarget
			     parser:[[ViParser alloc] initWithDefaultMap:map]];
}

- (void)presentError:(NSError *)error
{
	if ([target respondsToSelector:@selector(keyManager:presentError:)])
		[target performSelector:@selector(keyManager:presentError:)
			     withObject:self
			     withObject:error];
}

- (BOOL)handleKey:(NSInteger)keyCode error:(NSError **)outError
{
	[keyTimeout invalidate];

	if (keyCode == -1) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Internal error."];
		return NO;
	}

	SEL shouldSel = @selector(keyManager:shouldParseKey:);
	if ([target respondsToSelector:shouldSel]) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		    [target methodSignatureForSelector:shouldSel]];
		[invocation setSelector:shouldSel];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&keyCode atIndex:3];
		[invocation invokeWithTarget:target];
		BOOL shouldRet;
		[invocation getReturnValue:&shouldRet];
		if (shouldRet == NO)
			return YES; /* target handled the key already */
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
		[self presentError:error];
}

- (void)handleKeys:(NSArray *)keys
{
	for (NSNumber *n in keys)
		[self handleKey:[n integerValue]];
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
		[self presentError:error];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	BOOL partial = parser.partial;
	NSError *error = nil;
	if (![self handleKey:[theEvent normalizedKeyCode] error:&error]) {
		if (!partial && [error code] == ViErrorMapNotFound)
			return NO;
		[self presentError:error];
	}

	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	[self handleKey:[theEvent normalizedKeyCode]];
}

@end
