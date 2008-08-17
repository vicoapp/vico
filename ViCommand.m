#import "ViCommand.h"

#define has_flag(key, flag) ((((key)->flags) & flag) == flag)

#define VIF_NEED_MOTION	(1 << 0)
#define VIF_IS_MOTION	(1 << 1)
#define VIF_SETS_DOT	(1 << 2)
#define VIF_LINE_MODE	(1 << 3)
#define VIF_NEED_CHAR	(1 << 4)

static struct vikey vikeys[] = {
	{@"append_eol:",	'A', VIF_SETS_DOT},
	{@"insert_bol:",	'I', VIF_SETS_DOT},
	{@"goto_line:",		'G', VIF_IS_MOTION | VIF_LINE_MODE},
	{@"open_line_above:",	'O', VIF_SETS_DOT},
	{@"put_before:",	'P', VIF_SETS_DOT},
	{@"delete_backward:",	'X', VIF_SETS_DOT},
	{@"move_bol:",		'0', VIF_IS_MOTION},
	{@"append:",		'a', VIF_SETS_DOT},
	{@"word_backward:",	'b', VIF_IS_MOTION},
	{@"change:",		'c', VIF_NEED_MOTION | VIF_SETS_DOT},
	{@"delete:",		'd', VIF_NEED_MOTION | VIF_SETS_DOT},
	{@"move_to_char:",	'f', VIF_IS_MOTION | VIF_NEED_CHAR},
	{@"move_left:",		'h', VIF_IS_MOTION},
	{@"insert:",		'i', VIF_SETS_DOT},
	{@"move_down:",		'j', VIF_IS_MOTION | VIF_LINE_MODE},
	{@"move_up:",		'k', VIF_IS_MOTION | VIF_LINE_MODE},
	{@"move_right:",	'l', VIF_IS_MOTION},
	{@"open_line_below:",	'o', VIF_SETS_DOT},
	{@"put_after:",		'p', VIF_SETS_DOT},
	{@"move_til_char:",	't', VIF_IS_MOTION | VIF_NEED_CHAR},
	{@"word_forward:",	'w', VIF_IS_MOTION},
	{@"delete_forward:",	'x', VIF_SETS_DOT},
	{@"yank:",		'y', VIF_NEED_MOTION | VIF_SETS_DOT},
	{@"move_eol:",		'$', VIF_IS_MOTION},
	{nil, -1, 0}
};

static struct vikey *
find_command(int key)
{
	int i;
	for(i = 0; vikeys[i].method; i++)
	{
		if(vikeys[i].key == key)
			return &vikeys[i];
	}

	return NULL;
}

@implementation ViCommand

@synthesize complete;
@synthesize method;
@synthesize count;
@synthesize motion_count;
@synthesize key;
@synthesize character;

/* finalizes the command, sets the dot command and adjusts counts if necessary
 */
- (void)setComplete
{
	complete = YES;

	if(command_key && has_flag(command_key, VIF_SETS_DOT))
	{
		/* set the dot command parameters */
		dot_command_key = command_key;
		dot_motion_key = motion_key;
		dot_count = count;
		dot_motion_count = motion_count;
	}
	
	if(command_key && (command_key->key == 't' || command_key->key == 'f' ||
			   command_key->key == 'T' || command_key->key == 'F'))
	{
		last_ftFT_key = command_key;
		last_ftFT_character = character;
	}
	else if(motion_key && (motion_key->key == 't' || motion_key->key == 'f' ||
			       motion_key->key == 'T' || motion_key->key == 'F'))
	{
		last_ftFT_key = motion_key;
		last_ftFT_character = character;
	}
	
	if(count > 0 && motion_count > 0)
	{
		/* From nvi:
		 * A count may be provided both to the command and to the motion, in
		 * which case the count is multiplicative.  For example, "3y4y" is the
		 * same as "12yy".  This count is provided to the motion command and 
		 * not to the regular function.
		 */
		motion_count *= count;
		count = 0;
	}
}

- (void)pushKey:(unichar)aKey
{
	if(state == ViCommandNeedChar)
	{
		character = aKey;
		[self setComplete];

		return;
	}
	
	// check if it's a repeat count
	int *countp = nil;
	if(state == ViCommandInitialState)
		countp = &count;
	else if(state == ViCommandNeedMotion)
		countp = &motion_count;
	// conditionally include '0' as a repeat count only if it's not the first digit
	if(aKey >= '1' - ((countp && *countp > 0) ? 1 : 0) && aKey <= '9')
	{
		*countp *= 10;
		*countp += aKey - '0';
		return;
	}

	// check for the dot command
	if(aKey == '.')
	{
		if(dot_command_key == nil)
		{
			method = @"nodot:"; // prints "No command to repeat"
			[self setComplete];
			return;
		}

		command_key = dot_command_key;
		method = dot_command_key->method;
		motion_key = dot_motion_key;
		motion_count = dot_motion_count;
		key = dot_command_key->key;
		[self setComplete];
		return;
	}
	else if(aKey == ';' || aKey == ',')
	{
		if(last_ftFT_key == nil)
		{
			method = @"no_previous_ftFT:"; // prints "No previous F, f, T or t search"
		}
		else
		{
			NSLog(@"repeating '%c' command for char '%c'", last_ftFT_key->key, last_ftFT_character);
			command_key = last_ftFT_key;
			method = last_ftFT_key->method;
			character = last_ftFT_character;
			key = last_ftFT_key->key;
		}
		[self setComplete];
		return;
	}

	struct vikey *vikey = find_command(aKey);
	if(vikey == NULL)
	{
		// should print "X isn't a vi command"
		method = @"illegal:";
		key = aKey;
		[self setComplete];
		return;
	}

	if(state == ViCommandInitialState)
	{
		command_key = vikey;
		method = command_key->method;
		key = aKey;
		if(has_flag(vikey, VIF_NEED_MOTION))
		{
			state = ViCommandNeedMotion;
		}
		else if(has_flag(vikey, VIF_NEED_CHAR))
		{
			// VIF_NEED_CHAR and VIF_NEED_MOTION are mutually exclusive
			state = ViCommandNeedChar;
		}
		else
			[self setComplete];
	}
	else if(state == ViCommandNeedMotion)
	{
		if(has_flag(vikey, VIF_IS_MOTION))
		{
			motion_key = vikey;
		}
		else if(aKey == command_key->key)
		{
			/* From nvi:
			 * Commands that have motion components can be doubled to
			 * imply the current line.
			 *
			 * Do this by setting the line mode flag.
			 */
			motion_key = command_key;
		}
		else
		{
			// should print "X may not be used as a motion command"
			method = @"nonmotion:";
		}

		if(has_flag(vikey, VIF_NEED_CHAR))
		{
			state = ViCommandNeedChar;
		}
		else
		{
			[self setComplete];
		}
	}
}

- (void)reset
{
	complete = NO;
	method = nil;
	command_key = NULL;
	motion_key = NULL;
	state = ViCommandInitialState;
	count = 0;
	motion_count = 0;
	key = -1;
	character = -1;
}

- (int)ismotion
{
	if(command_key && has_flag(command_key, VIF_IS_MOTION))
		return 1;
	return 0;
}

- (BOOL)line_mode
{
	if(motion_key)
	{
		if(motion_key == command_key)
			return YES;
		return has_flag(motion_key, VIF_LINE_MODE);
	}
	return command_key && has_flag(command_key, VIF_LINE_MODE);
}

- (NSString *)motion_method
{
	if(motion_key && has_flag(motion_key, VIF_IS_MOTION))
		return motion_key->method;
	return nil;
}

@end
