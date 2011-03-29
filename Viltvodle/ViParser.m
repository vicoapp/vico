#import "ViParser.h"
#import "ViError.h"
#import "NSString-additions.h"
#import "logging.h"

@interface ViParser (private)
- (ViCommand *)handleKeySequenceInScope:(NSArray *)scopeArray
                             didTimeout:(BOOL)didTimeout
                                timeout:(BOOL *)timeoutPtr
                                  error:(NSError **)outError;
@end

@implementation ViParser

@synthesize nviStyleUndo;
@synthesize last_ftFT_command;
@synthesize last_search_pattern;
@synthesize last_search_options;

- (ViParser *)initWithDefaultMap:(ViMap *)aMap
{
	if ((self = [super init]) != nil) {
		defaultMap = aMap;
		[self reset];
	}
	return self;
}

- (ViCommand *)fail:(NSError **)outError with:(NSInteger)code message:(NSString *)fmt, ...
{
	if (outError) {
		va_list ap;
		va_start(ap, fmt);
		NSString *msg = [[NSString alloc] initWithFormat:fmt
						       arguments:ap];
		*outError = [ViError errorWithObject:msg code:code];
		va_end(ap);
	}
	[self reset];
	return nil;
}

/* finalizes the command, sets the dot command and adjusts counts if necessary
 */
- (ViCommand *)completeWithError:(NSError **)outError
{
	DEBUG(@"complete, command = %@, motion = %li", command, command.motion);

	/* FIXME: we might have unused excess keys here, should issue a
	 * warning/notice message that we discarded them.
	 */

	if ([command isDot]) {
		/* From nvi:
		 * !!!
		 * If a '.' is immediately entered after an undo command, we
		 * replay the log instead of redoing the last command.  This
		 * is necessary because 'u' can't set the dot command -- see
		 * vi/v_undo.c:v_undo for details.
		 */
		if (nviStyleUndo && [last_command isUndo])
			command = [last_command dotCopy];
		else if (dot_command == nil)
			return [self fail:outError
				     with:ViErrorParserNoDot
				  message:@"No command to repeat."];
		else {
			int dot_count = command.count;
			command = [dot_command dotCopy];
			if (dot_count > 0) {
				DEBUG(@"override count %i/%i with %i",
				    command.count, command.motion.count, dot_count);
				command.count = dot_count;
				command.motion.count = 0;
			}
		}
	} else if (command.mapping.action == @selector(move_til_char:) ||
	    command.mapping.action == @selector(move_to_char:) ||
	    command.mapping.action == @selector(move_back_til_char:) ||
	    command.mapping.action == @selector(move_back_to_char:)) {
		last_ftFT_command = command;
	} else if (command.motion.mapping.action == @selector(move_til_char:) ||
	    command.motion.mapping.action == @selector(move_to_char:) ||
	    command.motion.mapping.action == @selector(move_back_til_char:) ||
	    command.motion.mapping.action == @selector(move_back_to_char:)) {
		last_ftFT_command = command;
	}

	last_command = command;

	if ((command.mapping.flags & ViMapSetsDot) == ViMapSetsDot) {
		/* set the dot command */
		dot_command = command;

		/* new (real) commands reset the associated text */
//		if (!is_dot)
//			[self setText:nil];
	}

	if (command.count > 0 && command.motion && command.motion.count > 0) {
		/* From nvi:
		 * A count may be provided both to the command and to the motion, in
		 * which case the count is multiplicative.  For example, "3y4y" is the
		 * same as "12yy".  This count is provided to the motion command and 
		 * not to the regular function.
		 */
		command.motion.count = command.count * command.motion.count;
		command.count = 0;
	} else if (command.count > 0 && command.motion && command.motion.count == 0) {
		/*
		 * If a count is given to an operator command, attach the count
		 * to the motion command instead.
		 */
		command.motion.count = command.count;
		command.count = 0;
	}

	ViCommand *ret = command;
	[self reset];
	return ret;
}

- (ViCommand *)pushExcessKeys:(NSArray *)excessKeys
                        scope:(NSArray *)scopeArray
                      timeout:(BOOL *)timeoutPtr
                        error:(NSError **)outError
{
	for (NSNumber *n in excessKeys) {
		NSError *error = nil;
		ViCommand *c = [self pushKey:[n integerValue]
				       scope:scopeArray
				     timeout:timeoutPtr
				       error:&error];
		if (c == nil && error) {
			if (outError)
				*outError = error;
			[self reset];
			break;
		}

		if (c)
			/* XXX: what if we have more excess keys? Error or warning? */
			return c;
	}

	return nil;
}

- (ViCommand *)timeoutInScope:(NSArray *)scopeArray
                        error:(NSError **)outError
{
	return [self handleKeySequenceInScope:scopeArray
				   didTimeout:YES
				      timeout:nil
				        error:outError];
}

- (ViCommand *)pushKey:(NSInteger)keyCode
{
	return [self pushKey:keyCode scope:nil timeout:nil error:nil];
}

- (ViCommand *)pushKey:(NSInteger)keyCode
                 scope:(NSArray *)scopeArray
               timeout:(BOOL *)timeoutPtr
                 error:(NSError **)outError
{
	DEBUG(@"got key %@ in state %d", [NSString stringWithKeyCode:keyCode], state);
	
	unichar singleKey = 0;
	if ((keyCode & 0xFFFF0000) == 0)
		singleKey = keyCode & 0x0000FFFF;

	if (state == ViParserNeedChar) {
		if (!singleKey) {
			/* Got a key equivalent as argument. */
			return [self fail:outError
				     with:ViErrorParserInvalidArgument
				  message:@"Invalid argument: %@", [NSString stringWithKeyCode:keyCode]];
		}
		if (command.motion)
			command.motion.argument = singleKey;
		else
			command.argument = singleKey;
		return [self completeWithError:outError];
	} else if (state == ViParserNeedRegister) {
		if (!singleKey) {
			/* Got a key equivalent as register. */
			return [self fail:outError
				     with:ViErrorParserInvalidRegister
				  message:@"Invalid register: %@", [NSString stringWithKeyCode:keyCode]];
		}
		if (reg) {
			/* nvi says: "Only one buffer may be specified." */
			return [self fail:outError
				     with:ViErrorParserMultipleRegisters
				  message:@"Only one register may be specified."];
		}
		reg = singleKey;
		state = ViParserInitialState;
		return nil;
	}

	/* XXX: this makes it impossible to map " (but who would want to?) */
	if (singleKey == '"') {
		/* Expecting a register. */
		if (state == ViParserInitialState) {
			state = ViParserNeedRegister;
			return nil;
		} else if (state == ViParserNeedMotion) {
			/* nvi says: "Buffers should be specified before the command." */
			return [self fail:outError
				     with:ViErrorParserRegisterOrder
				  message:@"Registers should be specified"
					   " before the command."];
		} else
			DEBUG(@"got register in state %d ?", state);
	}

	/* Check if it's a repeat count, unless we're in the insert map. */
	/* FIXME: only in initial and operator-pending state, right? */
	/* FIXME: Some multi-key commands accepts counts in between, eg ctrl-w */
	if ([map acceptsCounts]) {
		/*
		 * Conditionally include '0' as a repeat count only
		 * if it's not the first digit.
		 */
		if (singleKey >= '1' - (count > 0 ? 1 : 0) &&
		    singleKey <= '9') {
			count *= 10;
			count += singleKey - '0';
			DEBUG(@"count is now %i", count);
			return nil;
		}
	}

	if (state == ViParserNeedMotion &&
	    keyCode == [[command.mapping.keySequence lastObject] integerValue]) {
		/*
		 * Operators can be doubled to imply the current line.
		 * Do this by setting the line mode flag.
		 */
		command.isLineMode = YES;
		/*
		 * We might get another count, but we don't have a motion
		 * command, so do any updating here. This duplicates the
		 * work done in completeWithError:.
		 * Example: 2d3d = 6dd
		 */
		if (count) {
			if (command.count)
				command.count = command.count * count;
			else
				command.count = count;
		}
		return [self completeWithError:outError];
	}

	if (map == NULL)
		map = defaultMap;

	NSNumber *num = [NSNumber numberWithInteger:keyCode];
	[keySequence addObject:num];
	[totalKeySequence addObject:num];

	return [self handleKeySequenceInScope:scopeArray
				   didTimeout:NO
				      timeout:timeoutPtr
				        error:outError];
}

- (ViCommand *)handleKeySequenceInScope:(NSArray *)scopeArray
                             didTimeout:(BOOL)didTimeout
                                timeout:(BOOL *)timeoutPtr
                                  error:(NSError **)outError
{
	NSError *error = nil;
	NSArray *excessKeys = nil;
	BOOL timeout = didTimeout;
	ViMapping *mapping = [map lookupKeySequence:keySequence
					  withScope:scopeArray
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
		if (state == ViParserInitialState)
			state = ViParserPartialCommand;
		else if (state == ViParserNeedMotion)
			state = ViParserPartialMotion;
		return nil;
	}

	if (![mapping isAction])
		return [self fail:outError
			     with:-1
			  message:@"macros not yet supported."];

	keySequence = [NSMutableArray array];

	if (state == ViParserInitialState || state == ViParserPartialCommand) {
		command = [ViCommand commandWithMapping:mapping];
		command.count = count;
		count = 0;
		// FIXME: check if a register is valid for the mapping?
		command.reg = reg;
		if ([mapping isOperator]) {
			state = ViParserNeedMotion;
			if ((map = map.operatorMap) == nil) {
				return [self fail:outError
					     with:ViErrorParserNoOperatorMap
					  message:@"No operator map for map %@.",
						 [map name]];
			}
			DEBUG(@"%@ is an operator, using operatorMap", mapping);
		} else if ([mapping needsArgument])
			state = ViParserNeedChar;
		else
			return [self completeWithError:outError];
	} else if (state == ViParserNeedMotion || state == ViParserPartialMotion) {
		DEBUG(@"got motion command %@", mapping);
		if (![mapping isMotion])
			return [self fail:outError
				     with:ViErrorParserInvalidMotion
				  message:@"%@ may not be used as a motion command.",
					 mapping.keyString];

		command.motion = [ViCommand commandWithMapping:mapping];
		command.motion.count = count;
		command.motion.operator = command;
		command.isLineMode = command.motion.mapping.isLineMode;
		count = 0;

		if ([mapping needsArgument])
			state = ViParserNeedChar;
		else
			return [self completeWithError:outError];
	} else
		return [self fail:outError
			     with:ViErrorParserInternal
			  message:@"Internal error in vi parser."];

	/* If we got excess keys from the map, parse them now. */
	return [self pushExcessKeys:excessKeys
			      scope:scopeArray
			    timeout:timeoutPtr
			      error:outError];
}

- (void)reset
{
	DEBUG(@"%s", "resetting");
	keySequence = [NSMutableArray array];
	totalKeySequence = [NSMutableArray array];
	command = nil;
	state = ViParserInitialState;
	count = 0;
	map = defaultMap;
	reg = 0;
}

- (BOOL)partial
{
	return [totalKeySequence count] > 0;
}

- (void)setMap:(ViMap *)aMap
{
	map = aMap;
}

- (void)setVisualMap
{
	map = [ViMap visualMap];
}

- (void)setInsertMap
{
	map = [ViMap insertMap];
}

- (void)setExplorerMap
{
	map = [ViMap explorerMap];
}

- (NSString *)keyString
{
	return [NSString stringWithKeySequence:totalKeySequence];
}

@end
