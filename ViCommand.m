#import "ViCommand.h"

#define has_flag(key, flag) ((((key)->flags) & flag) == flag)

#define VIF_NEED_MOTION	(1 << 0)
#define VIF_IS_MOTION	(1 << 1)
#define VIF_SETS_DOT	(1 << 2)
#define VIF_LINE_MODE	(1 << 3)
#define VIF_NEED_CHAR	(1 << 4)

static struct vikey vikeys[] = {
	{@"append_eol:",	'A', VIF_SETS_DOT},
	{@"delete_eol:",	'D', VIF_SETS_DOT},
	{@"insert_bol:",	'I', VIF_SETS_DOT},
	{@"join:",		'J', VIF_SETS_DOT},
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
	{@"replace:",		'r', VIF_SETS_DOT | VIF_NEED_CHAR},
	{@"substitute:",	's', VIF_SETS_DOT},
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
@synthesize motion_key;
@synthesize argument;

/* finalizes the command, sets the dot command and adjusts counts if necessary
 */
- (void)setComplete
{
	complete = YES;

	if(command && has_flag(command, VIF_SETS_DOT))
	{
		/* set the dot command parameters */
		dot_command = command;
		dot_motion_command = motion_command;
		dot_count = count;
		dot_motion_count = motion_count;
	}
	
	if(command && (command->key == 't' || command->key == 'f' ||
			   command->key == 'T' || command->key == 'F'))
	{
		last_ftFT_command = command;
		last_ftFT_argument = argument;
	}
	else if(motion_command && (motion_command->key == 't' || motion_command->key == 'f' ||
			       motion_command->key == 'T' || motion_command->key == 'F'))
	{
		last_ftFT_command = motion_command;
		last_ftFT_argument = argument;
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
		argument = aKey;
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
		if(dot_command == nil)
		{
			method = @"nodot:"; // prints "No command to repeat"
			[self setComplete];
			return;
		}

		command = dot_command;
		method = dot_command->method;
		motion_command = dot_motion_command;
		motion_count = dot_motion_count;
		key = dot_command->key;
		if(dot_motion_command)
			motion_key = dot_motion_command->key;
		[self setComplete];
		return;
	}
	else if(aKey == ';' || aKey == ',')
	{
		if(last_ftFT_command == nil)
		{
			method = @"no_previous_ftFT:"; // prints "No previous F, f, T or t search"
		}
		else
		{
			NSLog(@"repeating '%c' command for char '%C'", last_ftFT_command->key, last_ftFT_argument);
			command = last_ftFT_command;
			method = last_ftFT_command->method;
			argument = last_ftFT_argument;
			key = last_ftFT_command->key;
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
		command = vikey;
		method = command->method;
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
		motion_key = aKey;

		if(has_flag(vikey, VIF_IS_MOTION))
		{
			motion_command = vikey;
		}
		else if(aKey == command->key)
		{
			/* From nvi:
			 * Commands that have motion components can be doubled to
			 * imply the current line.
			 *
			 * Do this by setting the line mode flag.
			 */
			motion_command = command;
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
	command = NULL;
	motion_command = NULL;
	state = ViCommandInitialState;
	count = 0;
	motion_count = 0;
	key = -1;
	argument = -1;
}

- (int)ismotion
{
	if(command && has_flag(command, VIF_IS_MOTION))
		return 1;
	return 0;
}

- (BOOL)line_mode
{
	if(motion_command)
	{
		if(motion_command == command)
			return YES;
		return has_flag(motion_command, VIF_LINE_MODE);
	}
	return command && has_flag(command, VIF_LINE_MODE);
}

- (NSString *)motion_method
{
	if(motion_command && has_flag(motion_command, VIF_IS_MOTION))
		return motion_command->method;
	return nil;
}

@end
