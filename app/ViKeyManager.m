#import "ViKeyManager.h"
#import "NSEvent-keyAdditions.h"
#import "NSString-additions.h"
#import "ViError.h"
#import "ViMacro.h"
#include "logging.h"

@interface ViKeyManager (private)
- (BOOL)handleKey:(NSInteger)keyCode
      allowMacros:(BOOL)allowMacros
            error:(NSError **)outError;
@end

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

- (void)runMacro:(ViMacro *)macro
{
	DEBUG(@"running macro %@", macro);

	if (++recursionLevel > 1000) {
		[self presentError:[ViError errorWithFormat:@"Recursive mapping."]];
		recursionLevel = 0;
		return;
	}

	NSInteger keyCode;
	NSError *error = nil;
	while ((keyCode = [macro pop]) != -1) {
		if ([self handleKey:keyCode
			allowMacros:macro.mapping.recursive
			      error:&error] == NO || error) {
			if (error)
				[self presentError:error];
		 	DEBUG(@"aborting macro on key %@",
			    [NSString stringWithKeyCode:keyCode]);
			return;
		}
	}

	recursionLevel = 0;
}

- (BOOL)handleKey:(NSInteger)keyCode
      allowMacros:(BOOL)allowMacros
            error:(NSError **)outError
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
				 allowMacros:allowMacros
				       scope:nil
				     timeout:&timeout
				       error:&error];
	if (command) {
		SEL action = @selector(keyManager:evaluateCommand:);
		if ([command isKindOfClass:[ViMacro class]])
			[self runMacro:command];
		else if ([target respondsToSelector:action])
			return (BOOL)[target performSelector:action
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
								     userInfo:nil
								      repeats:NO];
	}

	return YES;
}

- (BOOL)handleKey:(NSInteger)keyCode
{
	NSError *error = nil;
	BOOL ret = [self handleKey:keyCode allowMacros:YES error:&error];
	if (error)
		[self presentError:error];
	return ret;
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
		if ([command isKindOfClass:[ViMacro class]])
			[self runMacro:command];
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
	[self handleKey:[theEvent normalizedKeyCode] allowMacros:YES error:&error];
	if (error) {
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
