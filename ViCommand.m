#import "ViCommand.h"

#define has_flag(key, flag) ((((key)->flags) & flag) == flag)

#define VIF_NEED_MOTION	(1 << 0)
#define VIF_IS_MOTION	(2 << 0)

static struct vikey vikeys[] = {
	{@"append",		'a', 0},
	{@"append_eol",		'A', 0},
	{@"insert",		'i', 0},
	{@"insert_bol",		'I', 0},
	{@"change",		'c', VIF_NEED_MOTION},
	{@"delete",		'd', VIF_NEED_MOTION},
	{@"move_left",		'h', VIF_IS_MOTION},
	{@"move_down",		'j', VIF_IS_MOTION},
	{@"move_up",		'k', VIF_IS_MOTION},
	{@"move_right",		'l', VIF_IS_MOTION},
	{@"move_bol",		'0', VIF_IS_MOTION},
	{@"move_eol",		'$', VIF_IS_MOTION},
	{@"word_forward",	'w', VIF_IS_MOTION},
	{@"delete_forward",	'x', 0},
	{@"delete_backward",	'X', 0},
	{@"open_line_above",	'O', 0},
	{@"open_line_below",	'o', 0},
	{nil, 0, 0}
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
@synthesize motion_method;
@synthesize count;
@synthesize motion_count;
@synthesize start_range;
@synthesize stop_range;

- (void)pushKey:(unichar)key
{
	// check if it's a repeat count
	int *countp = nil;
	if(state == ViCommandInitialState)
		countp = &count;
	else if(state == ViCommandNeedMotion)
		countp = &motion_count;
	if(key >= '1' - ((countp && *countp > 0) ? 1 : 0) && key <= '9')
	{
		*countp *= 10;
		*countp += key - '0';
		return;
	}

	struct vikey *vikey = find_command(key);
	if(vikey == NULL)
	{
		// should print "X isn't a vi command"
		method = @"illegal";
		complete = YES;
		return;
	}

	if(state == ViCommandInitialState)
	{
		method = vikey->method;
		command_key = vikey;
		if(has_flag(vikey, VIF_NEED_MOTION))
			state = ViCommandNeedMotion;
		else
			complete = YES;
	}
	else if(state == ViCommandNeedMotion)
	{
		if(has_flag(vikey, VIF_IS_MOTION))
		{
			motion_method = vikey->method;
		}
		else if(key == command_key->key)
		{
			/* From nvi:
			 * Commands that have motion components can be doubled to
			 * imply the current line.
			 */
			motion_method = @"current_line";
		}
		else
		{
			// should print "X may not be used as a motion command"
			method = @"nonmotion";
		}
		complete = YES;
	}

}

- (void)reset
{
	complete = NO;
	method = nil;
	motion_method = nil;
	command_key = NULL;
	state = ViCommandInitialState;
	count = 0;
	motion_count = 0;
}

- (int)key
{
	if(command_key)
		return command_key->key;
	return -1;
}

@end
