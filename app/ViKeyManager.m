#import "ViKeyManager.h"
#import "NSEvent-keyAdditions.h"
#import "NSString-additions.h"
#import "ViError.h"
#import "ViMacro.h"
#import "ViAppController.h"
#include "logging.h"

@interface ViKeyManager (private)
- (BOOL)handleKey:(NSInteger)keyCode
      allowMacros:(BOOL)allowMacros
          inScope:(ViScope *)scope
	fromMacro:(ViMacro *)callingMacro
       excessKeys:(NSArray **)excessKeys
            error:(NSError **)outError;
@end

@implementation ViKeyManager

@synthesize parser = _parser;
@synthesize target = _target;

+ (ViKeyManager *)keyManagerWithTarget:(id<ViKeyManagerTarget>)aTarget
				parser:(ViParser *)aParser
{
	return [[[ViKeyManager alloc] initWithTarget:aTarget parser:aParser] autorelease];
}

+ (ViKeyManager *)keyManagerWithTarget:(id<ViKeyManagerTarget>)aTarget
			    defaultMap:(ViMap *)map
{
	return [[[ViKeyManager alloc] initWithTarget:aTarget defaultMap:map] autorelease];
}

- (ViKeyManager *)initWithTarget:(id<ViKeyManagerTarget>)aTarget
                          parser:(ViParser *)aParser
{
	if ((self = [super init]) != nil) {
		_parser = [aParser retain];
		_target = aTarget; // XXX: not retained!
	}
	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_parser release];
	[_keyTimeout release];
	[super dealloc];
}

- (ViKeyManager *)initWithTarget:(id<ViKeyManagerTarget>)aTarget
                      defaultMap:(ViMap *)map
{
	return [self initWithTarget:aTarget
			     parser:[ViParser parserWithDefaultMap:map]];
}

- (void)presentError:(NSError *)error
{
	if ([_target respondsToSelector:@selector(keyManager:presentError:)])
		[_target performSelector:@selector(keyManager:presentError:)
			      withObject:self
			      withObject:error];
}

- (BOOL)runMacro:(ViMacro *)macro interactively:(BOOL)interactiveFlag
{
	DEBUG(@"running macro %@ %sinteractively", macro, interactiveFlag ? "" : "NOT ");

	if (++_recursionLevel > 1000) {
		[self presentError:[ViError errorWithFormat:@"Recursive mapping."]];
		_recursionLevel = 0;
		return NO;
	}

	/*
	 * Evaluate macro as a Nu expression.
	 */
	if ([macro.mapping isExpression]) {
		NuBlock *expression = macro.mapping.expression;
		DEBUG(@"evaling with calling context %@", [expression context]);
		@try {
			id result = [[expression body] evalWithContext:[expression context]];
			DEBUG(@"got result %@, class %@", result, NSStringFromClass([result class]));
			return [result respondsToSelector:@selector(boolValue)] && [result boolValue];
		}
		@catch (NSException *exception) {
			INFO(@"got exception %@ while evaluating expression:\n%@", [exception name], [exception reason]);
			INFO(@"context was: %@", [expression context]);
			[self presentError:[ViError errorWithFormat:@"Got exception %@: %@",
			    [exception name], [exception reason]]];
			_recursionLevel = 0;
			return NO;
		}
	}

	NSInteger keyCode;
	NSError *error = nil;
	while ((keyCode = [macro pop]) != -1) {
		/*
		 * Send the key to the key manager of the first responder.
		 * First responder might be another buffer, or the ex command line.
		 */
		ViKeyManager *km = self;
		if (interactiveFlag) {
			NSResponder *responder = [[NSApp keyWindow] firstResponder];
			if ([responder respondsToSelector:@selector(keyManager)])
				km = [responder performSelector:@selector(keyManager)];
		}

#ifndef NO_DEBUG
		if (km == self)
			DEBUG(@"evaluating key %@", [NSString stringWithKeyCode:keyCode]);
		else
			DEBUG(@"evaluating key %@ with keymanager %@", [NSString stringWithKeyCode:keyCode], km);
#endif

		NSArray *excessKeys = nil;
		if ([km handleKey:keyCode
		      allowMacros:macro.mapping.recursive
			  inScope:[self currentScope]
			fromMacro:macro
		       excessKeys:&excessKeys
			    error:&error] == NO || error) {
			if (error) {
				DEBUG(@"error: %@", error);
				[self presentError:error];
			}
		 	DEBUG(@"aborting macro on key %@",
			    [NSString stringWithKeyCode:keyCode]);
			return NO;
		}

		if (excessKeys) {
			DEBUG(@"pushing back excess keys %@", excessKeys);
			for (NSNumber *n in excessKeys)
				[macro push:n];
		}
	}

	_recursionLevel = 0;
	return YES;
}

- (BOOL)runMacro:(ViMacro *)macro
{
	return [self runMacro:macro interactively:YES];
}

- (BOOL)runAsMacro:(NSString *)inputString interactively:(BOOL)interactiveFlag
{
	ViMapping *m = [ViMapping mappingWithKeySequence:nil
						   macro:inputString
					       recursive:YES
						   scope:nil];
	ViMacro *macro = [ViMacro macroWithMapping:m prefix:nil];
	return [self runMacro:macro interactively:interactiveFlag];
}

- (BOOL)runAsMacro:(NSString *)inputString
{
	return [self runAsMacro:inputString interactively:YES];
}

- (BOOL)evalCommand:(id)command
{
	if ([command isKindOfClass:[ViMacro class]])
		return [self runMacro:command];

	SEL action = @selector(keyManager:evaluateCommand:);
	if ([_target respondsToSelector:action])
		return (BOOL)[_target performSelector:action
					   withObject:self
					   withObject:command];

	return NO;
}

- (BOOL)handleKey:(NSInteger)keyCode
      allowMacros:(BOOL)allowMacros
          inScope:(ViScope *)scope
	fromMacro:(ViMacro *)callingMacro
       excessKeys:(NSArray **)excessKeys
            error:(NSError **)outError
{
	[_keyTimeout invalidate];
	[_keyTimeout release];
	_keyTimeout = nil;

	DEBUG(@"handling key %li (%@) in scope %@", keyCode, [NSString stringWithKeyCode:keyCode], scope);

	if (keyCode == -1) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Internal error."];
		return NO;
	}

	SEL shouldSel = @selector(keyManager:shouldParseKey:inScope:);
	if ([_target respondsToSelector:shouldSel]) {
		NSNumber *keyNum = [NSNumber numberWithInteger:keyCode];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		    [(NSObject *)_target methodSignatureForSelector:shouldSel]];
		[invocation setSelector:shouldSel];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&keyNum atIndex:3];
		[invocation setArgument:&scope atIndex:4];
		[invocation invokeWithTarget:_target];
		NSNumber *shouldRet;
		[invocation getReturnValue:&shouldRet];
		if ([shouldRet boolValue] == NO)
			return YES; /* target handled the key already */
	}

	NSError *error = nil;
	BOOL timeout = NO;
	id command = [_parser pushKey:keyCode
			  allowMacros:allowMacros
				scope:scope
			      timeout:&timeout
			   excessKeys:excessKeys
				error:&error];
	if (command) {
		if ([command isKindOfClass:[ViCommand class]])
			[command setMacro:callingMacro];
		return [self evalCommand:command];
	} else if (error) {
		if (outError)
			*outError = error;
		return NO;
	} else {
		if ([_target respondsToSelector:@selector(keyManager:partialKeyString:)])
			[_target performSelector:@selector(keyManager:partialKeyString:)
				      withObject:self
				      withObject:_parser.keyString];
		if (timeout && callingMacro == nil) {
			[_keyTimeout release];
			_keyTimeout = [[NSTimer scheduledTimerWithTimeInterval:1.0
									target:self
								      selector:@selector(keyTimedOut:)
								      userInfo:scope
								       repeats:NO] retain];
		}
	}

	return YES;
}

- (BOOL)handleKey:(NSInteger)keyCode inScope:(ViScope *)scope
{
	NSError *error = nil;
	NSArray *excessKeys = nil;
	BOOL ret = [self handleKey:keyCode
                       allowMacros:YES
                           inScope:scope
                         fromMacro:nil
                        excessKeys:&excessKeys
                             error:&error];
	if (error)
		[self presentError:error];
	else if (excessKeys) {
		if (ret == NO) {
			INFO(@"%lu excess keys discarded", [excessKeys count]);
			// [self presentError:[ViError errorWithFormat:@"Excess keys discarded."]];
		} else {
			NSUInteger i;
			for (i = 0; i < [excessKeys count]; i++) {
				NSInteger keyCode = [[excessKeys objectAtIndex:i] integerValue];
				ret = [self handleKey:keyCode inScope:scope];
				if (ret == NO) {
					if (i + 1 < [excessKeys count])
						INFO(@"%lu excess keys discarded", [excessKeys count] - (i + 1));
						// [self presentError:[ViError errorWithFormat:@"Excess keys discarded."]];
					return NO;
				}
			}
		}
	}
	return ret;
}

- (BOOL)handleKey:(NSInteger)keyCode
{
	return [self handleKey:keyCode inScope:nil];
}

- (void)handleKeys:(NSArray *)keys inScope:(ViScope *)scope
{
	for (NSNumber *n in keys)
		[self handleKey:[n integerValue] inScope:scope];
}

- (void)handleKeys:(NSArray *)keys
{
	[self handleKeys:keys inScope:nil];
}

- (void)keyTimedOut:(NSTimer *)timer
{
	NSError *error = nil;
	ViScope *scope = [timer userInfo];
	id command = [_parser timeoutInScope:scope error:&error];
	if (command)
		[self evalCommand:command];
	else if (error)
		[self presentError:error];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent inScope:(ViScope *)scope
{
	BOOL partial = _parser.partial;
	NSError *error = nil;
	NSArray *excessKeys = nil;
	[self handleKey:[theEvent normalizedKeyCode]
	    allowMacros:YES
		inScope:scope
	      fromMacro:nil
	     excessKeys:&excessKeys
		  error:&error];
	if (error) {
		if (!partial && [error code] == ViErrorMapNotFound)
			return NO;
		[self presentError:error];
	}

	/* FIXME: Should we handle excess keys here too? */
	if (excessKeys)
		[self presentError:[ViError errorWithFormat:@"Excess keys discarded."]];

	return YES;
}

- (ViScope *)currentScope
{
	ViScope *scope = nil;
	if ([[self target] respondsToSelector:@selector(currentScopeForKeyManager:)])
		scope = [[self target] performSelector:@selector(currentScopeForKeyManager:)
					    withObject:self];
	DEBUG(@"scope is %@", scope);
	return scope;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	return [self performKeyEquivalent:theEvent inScope:[self currentScope]];
}

- (void)keyDown:(NSEvent *)theEvent inScope:(ViScope *)scope
{
	[self handleKey:[theEvent normalizedKeyCode] inScope:scope];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[self keyDown:theEvent inScope:[self currentScope]];
}

@end
