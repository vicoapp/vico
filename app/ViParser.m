#import "ViParser.h"
#import "ViError.h"
#import "NSString-additions.h"
#import "ViMacro.h"
#import "logging.h"

@interface ViParser (private)
- (ViCommand *)handleKeySequenceInScope:(ViScope *)scope
                            allowMacros:(BOOL)allowMacros
                             didTimeout:(BOOL)didTimeout
                                timeout:(BOOL *)timeoutPtr
                                  error:(NSError **)outError;
@end

@implementation ViParser

@synthesize nviStyleUndo = _nviStyleUndo;
@synthesize lastLineSearchCommand = _lastLineSearchCommand;
@synthesize lastSearchOptions = _lastSearchOptions;
@synthesize map = _map;
@synthesize command = _command;
@synthesize dotCommand = _dotCommand;
@synthesize lastCommand = _lastCommand;

+ (ViParser *)parserWithDefaultMap:(ViMap *)aMap
{
	return [[[ViParser alloc] initWithDefaultMap:aMap] autorelease];
}

- (ViParser *)initWithDefaultMap:(ViMap *)aMap
{
	if ((self = [super init]) != nil) {
		_defaultMap = [aMap retain];
		_totalKeySequence = [[NSMutableArray alloc] init];
		[self reset];
	}
	return self;
}

- (void)dealloc
{
	[_defaultMap release];
	[_map release];
	[_command release];
	[_dotCommand release];
	[_lastCommand release];
	[_keySequence release];
	[_totalKeySequence release];
	[super dealloc];
}

- (id)fail:(NSError **)outError
      with:(NSInteger)code
   message:(NSString *)fmt, ...
{
	if (outError) {
		va_list ap;
		va_start(ap, fmt);
		NSString *msg = [[NSString alloc] initWithFormat:fmt
						       arguments:ap];
		*outError = [ViError errorWithObject:msg code:code];
		[msg release];
		va_end(ap);
	}
	[self reset];
	return nil;
}

/* finalizes the command, sets the dot command and adjusts counts if necessary
 */
- (ViCommand *)completeWithError:(NSError **)outError
{
	DEBUG(@"complete, command = %@, motion = %li", _command, _command.motion);
	_remainingExcessKeysPtr = nil;

	if ([_command isDot]) {
		/* From nvi:
		 * !!!
		 * If a '.' is immediately entered after an undo command, we
		 * replay the log instead of redoing the last command.  This
		 * is necessary because 'u' can't set the dot command -- see
		 * vi/v_undo.c:v_undo for details.
		 */
		if (_nviStyleUndo && [_lastCommand isUndo])
			[self setCommand:[[_lastCommand copy] autorelease]];
		else if (_dotCommand == nil)
			return [self fail:outError
				     with:ViErrorParserNoDot
				  message:@"No command to repeat."];
		else {
			int dot_count = _command.count;
			[self setCommand:[[_dotCommand copy] autorelease]];
			if (dot_count > 0) {
				DEBUG(@"override count %i/%i with %i",
				    _command.count, _command.motion.count, dot_count);
				_command.count = dot_count;
				_command.motion.count = 0;
			}
		}
	} else if (_command.action == @selector(move_til_char:) ||
	    _command.action == @selector(move_to_char:) ||
	    _command.action == @selector(move_back_til_char:) ||
	    _command.action == @selector(move_back_to_char:)) {
		[self setLastLineSearchCommand:_command];
	} else if (_command.motion.action == @selector(move_til_char:) ||
	    _command.motion.action == @selector(move_to_char:) ||
	    _command.motion.action == @selector(move_back_til_char:) ||
	    _command.motion.action == @selector(move_back_to_char:)) {
		[self setLastLineSearchCommand:_command];
	}

	[self setLastCommand:_command];

	if ((_command.mapping.flags & ViMapSetsDot) == ViMapSetsDot) {
		/* set the dot command */
		[self setDotCommand:_command];
	}

	if (_command.count > 0 && _command.motion && _command.motion.count > 0) {
		/* From nvi:
		 * A count may be provided both to the command and to the motion, in
		 * which case the count is multiplicative.  For example, "3y4y" is the
		 * same as "12yy".  This count is provided to the motion command and
		 * not to the regular function.
		 */
		_command.motion.count = _command.count * _command.motion.count;
		_command.count = 0;
	} else if (_command.count > 0 && _command.motion && _command.motion.count == 0) {
		/*
		 * If a count is given to an operator command, attach the count
		 * to the motion command instead.
		 */
		_command.motion.count = _command.count;
		_command.count = 0;
	}

	ViCommand *ret = [[_command retain] autorelease];
	[self reset];
	return ret;
}

- (id)pushExcessKeys:(NSArray *)excessKeys
         allowMacros:(BOOL)allowMacros
               scope:(ViScope *)scope
             timeout:(BOOL *)timeoutPtr
               error:(NSError **)outError
{
	NSUInteger i;
	for (i = 0; i < [excessKeys count]; i++) {
		NSNumber *n = [excessKeys objectAtIndex:i];
		NSError *error = nil;
		ViCommand *c = [self pushKey:[n integerValue]
				 allowMacros:allowMacros
				       scope:scope
				     timeout:timeoutPtr
				  excessKeys:_remainingExcessKeysPtr
				       error:&error];
		if (c == nil && error) {
			if (outError)
				*outError = error;
			[self reset];
			break;
		}

		if (c) {
			/* XXX: what if we have more excess keys? Error or warning? */
			if (i + 1 < [excessKeys count] && _remainingExcessKeysPtr)
				*_remainingExcessKeysPtr = [excessKeys subarrayWithRange:NSMakeRange(i + 1, [excessKeys count] - (i + 1))];
			return c;
		}
	}

	return nil;
}

- (id)timeoutInScope:(ViScope *)scope
               error:(NSError **)outError
{
	_remainingExcessKeysPtr = nil;
	return [self handleKeySequenceInScope:scope
				  allowMacros:YES	/* XXX: ? */
				   didTimeout:YES
				      timeout:nil
				        error:outError];
}

- (id)pushKey:(NSInteger)keyCode
{
	return [self pushKey:keyCode
                 allowMacros:YES
                       scope:nil
                     timeout:nil
                  excessKeys:nil
                       error:nil];
}

- (id)pushKey:(NSInteger)keyCode
  allowMacros:(BOOL)allowMacros
        scope:(ViScope *)scope
      timeout:(BOOL *)timeoutPtr
   excessKeys:(NSArray **)excessKeysPtr
        error:(NSError **)outError
{
	DEBUG(@"got key 0x%04x, or %@ in state %d", keyCode, [NSString stringWithKeyCode:keyCode], _state);

	_remainingExcessKeysPtr = excessKeysPtr;

	NSNumber *keyNum = [NSNumber numberWithInteger:keyCode];
	[_totalKeySequence addObject:keyNum];

	unichar singleKey = 0;
	if ((keyCode & 0xFFFF0000) == 0)
		singleKey = keyCode & 0x0000FFFF;

	if (_state == ViParserNeedChar) {
		if (!singleKey) {
			/* Got a key equivalent as argument. */
			return [self fail:outError
				     with:ViErrorParserInvalidArgument
				  message:@"Invalid argument: %@", [NSString stringWithKeyCode:keyCode]];
		}
		if (_command.motion)
			_command.motion.argument = singleKey;
		else
			_command.argument = singleKey;
		return [self completeWithError:outError];
	} else if (_state == ViParserNeedRegister) {
		if (!singleKey) {
			/* Got a key equivalent as register. */
			return [self fail:outError
				     with:ViErrorParserInvalidRegister
				  message:@"Invalid register: %@", [NSString stringWithKeyCode:keyCode]];
		}
		if (_reg) {
			/* nvi says: "Only one buffer may be specified." */
			return [self fail:outError
				     with:ViErrorParserMultipleRegisters
				  message:@"Only one register may be specified."];
		}
		_reg = singleKey;
		_state = ViParserInitialState;
		return nil;
	}

	/* XXX: this makes it impossible to map " (but who would want to?) */
	if (singleKey == '"' && [_map acceptsCounts]) {
		/* Expecting a register. */
		if (_state == ViParserInitialState) {
			_state = ViParserNeedRegister;
			return nil;
		} else if (_state == ViParserNeedMotion) {
			/* nvi says: "Buffers should be specified before the command." */
			return [self fail:outError
				     with:ViErrorParserRegisterOrder
				  message:@"Registers should be specified"
					   " before the command."];
		} else
			DEBUG(@"got register in state %d ?", _state);
	}

	if (_map == nil)
		[self setMap:_defaultMap];

	/* Check if it's a repeat count, unless we're in the insert map. */
	/* FIXME: only in initial and operator-pending state, right? */
	/* FIXME: Some multi-key commands accepts counts in between, eg ctrl-w */
	if ([_map acceptsCounts]) {
		/*
		 * Conditionally include '0' as a repeat count only
		 * if it's not the first digit.
		 */
		if (singleKey >= '1' - (_count > 0 ? 1 : 0) && singleKey <= '9') {
			/*
			 * If we're in an partial/ambiguous command, test if the
			 * count results in an unambiguous command that needs an
			 * argument. In that case, the key is not a count, but
			 * an argument.
			 */
			BOOL useCount = YES;
			if (_state == ViParserPartialCommand) {
				NSArray *testSequence = [_keySequence arrayByAddingObject:keyNum];
				ViMapping *mapping = [_map lookupKeySequence:testSequence
								   withScope:scope
								 allowMacros:allowMacros
								  excessKeys:nil
								     timeout:nil
								       error:nil];
				if ([mapping needsArgument])
					useCount = NO;
			}

			if (useCount) {
				_count *= 10;
				_count += singleKey - '0';
				DEBUG(@"count is now %i", _count);
				return nil;
			}
		}
	}

	if (_state == ViParserNeedMotion &&
	    keyCode == [[_command.mapping.keySequence lastObject] integerValue]) {
		/*
		 * Operators can be doubled to imply the current line.
		 * Do this by setting the line mode flag.
		 */
		_command.isLineMode = YES;
		/*
		 * We might get another count, but we don't have a motion
		 * command, so do any updating here. This duplicates the
		 * work done in completeWithError:.
		 * Example: 2d3d = 6dd
		 */
		if (_count) {
			if (_command.count)
				_command.count = _command.count * _count;
			else
				_command.count = _count;
		}
		return [self completeWithError:outError];
	}

	[_keySequence addObject:keyNum];
	return [self handleKeySequenceInScope:scope
				  allowMacros:allowMacros
				   didTimeout:NO
				      timeout:timeoutPtr
				        error:outError];
}

- (id)handleKeySequenceInScope:(ViScope *)scope
                   allowMacros:(BOOL)allowMacros
                    didTimeout:(BOOL)didTimeout
                       timeout:(BOOL *)timeoutPtr
                         error:(NSError **)outError
{
	NSError *error = nil;
	NSArray *excessKeys = nil;
	BOOL timeout = didTimeout;
	ViMapping *mapping = [_map lookupKeySequence:_keySequence
					   withScope:scope
					 allowMacros:allowMacros
					  excessKeys:&excessKeys
					     timeout:&timeout
					       error:&error];
	if (timeoutPtr)
		*timeoutPtr = timeout;
	if (mapping == nil) {
		if (error) {
			if (outError)
				*outError = error;
			[self reset];
			return nil;
		}

		/* Multiple matches, we need more keys to disambiguate. */
		if (_state == ViParserInitialState)
			_state = ViParserPartialCommand;
		else if (_state == ViParserNeedMotion)
			_state = ViParserPartialMotion;
		return nil;
	}

	if ([mapping isMacro]) {
		if (!allowMacros) {
			if (outError)
				*outError = [ViError errorWithFormat:
				    @"Internal error in key parser."];
			[self reset];
			return nil;
		}

		/*
		 * Create a new macro that concatenates the currently
		 * typed keys (including register, count and operator)
		 * with the mapped keys.
		 */

		/* totalKeySequence - keySequence = macro prefix */
		NSRange r = NSMakeRange(0, [_totalKeySequence count] - [_keySequence count]);
		NSArray *prefix = [_totalKeySequence subarrayWithRange:r];

		ViMacro *macro = [ViMacro macroWithMapping:mapping
						    prefix:prefix];
		[self reset];
		DEBUG(@"returning macro %@", macro);
		return macro;
	}

	[_keySequence release];
	_keySequence = [[NSMutableArray alloc] init];

	if (_state == ViParserInitialState || _state == ViParserPartialCommand) {
		[_command release]; // XXX: should already be nil from [reset], right?
		_command = [[ViCommand alloc] initWithMapping:mapping count:_count];
		_count = 0;
		// FIXME: check if a register is valid for the mapping?
		_command.reg = _reg;
		if ([mapping isOperator]) {
			_state = ViParserNeedMotion;
			if (_map.operatorMap == nil)
				return [self fail:outError
					     with:ViErrorParserNoOperatorMap
					  message:@"No operator map for map %@.",
						 _map.name];
			[self setMap:_map.operatorMap];
			DEBUG(@"%@ is an operator, using operatorMap %@", mapping, _map);
		} else if ([mapping needsArgument])
			_state = ViParserNeedChar;
		else {
			if (_remainingExcessKeysPtr)
				*_remainingExcessKeysPtr = excessKeys;
			return [self completeWithError:outError];
		}
	} else if (_state == ViParserNeedMotion || _state == ViParserPartialMotion) {
		DEBUG(@"got motion command %@", mapping);
		if (![mapping isMotion])
			return [self fail:outError
				     with:ViErrorParserInvalidMotion
				  message:@"%@ may not be used as a motion command.",
					 mapping.keyString];

		_command.motion = [ViCommand commandWithMapping:mapping count:_count];
		[_command.motion setOperator:_command];
		if (!_command.isLineMode)
			_command.isLineMode = _command.motion.mapping.isLineMode;
		_count = 0;

		if ([mapping needsArgument])
			_state = ViParserNeedChar;
		else {
			if (_remainingExcessKeysPtr)
				*_remainingExcessKeysPtr = excessKeys;
			return [self completeWithError:outError];
		}
	} else
		return [self fail:outError
			     with:ViErrorParserInternal
			  message:@"Internal error in key parser with map %@.",
				_map.name];

	/* If we got excess keys from the map, parse them now. */
	return [self pushExcessKeys:excessKeys
			allowMacros:allowMacros
			      scope:scope
			    timeout:timeoutPtr
			      error:outError];
}

- (void)reset
{
	DEBUG(@"%s", "resetting");
	[_keySequence release];
	_keySequence = [[NSMutableArray alloc] init];

	[_totalKeySequence removeAllObjects];

	[_command release];
	_command = nil;

	_state = ViParserInitialState;
	_count = 0;

	[_defaultMap retain];
	[_map release];
	_map = _defaultMap;

	_reg = 0;
}

- (BOOL)partial
{
	return [_totalKeySequence count] > 0;
}

- (void)setVisualMap
{
	[self setMap:[ViMap visualMap]];
}

- (void)setInsertMap
{
	[self setMap:[ViMap insertMap]];
}

- (void)setExplorerMap
{
	[self setMap:[ViMap explorerMap]];
}

- (NSString *)keyString
{
	return [NSString stringWithKeySequence:_totalKeySequence];
}

@end
