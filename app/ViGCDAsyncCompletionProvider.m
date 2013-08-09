#import "ViGCDAsyncCompletionProvider.h"

@implementation ViGCDAsyncCompletionProvider

- (ViGCDAsyncCompletionProvider *)init
{
	if (self = [super init]) {
		_completionsSoFar = [[NSMutableArray array] retain];
		_completionReceiver = nil;
	}

	return self;
}

- (NSArray *)completionsForString:(NSString *)string
						  options:(NSString *)options
							error:(NSError **)outError
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	  [self startCompleting];
	});

	return [NSArray array];
}

- (void)setCompletionReceiver:(id<ViCompletionReceiver>)completionReceiver
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		_completionReceiver = completionReceiver;

		if ([_completionsSoFar count] > 0) {
			// Trigger an async push of completions received so far to the new receiver.
			[self completionsReceived:[NSArray array]];
		}
	});
}

- (void)completionsReceived:(NSArray *)completions
{
	[_completionsSoFar addObjectsFromArray:completions];
	NSArray *allCompletions = [NSArray arrayWithArray:_completionsSoFar];

	dispatch_async(dispatch_get_main_queue(), ^{
		if (_completionReceiver) {
			[_completionReceiver completionResponse:allCompletions error:nil];
		}
	});
}

- (void)startCompleting
{
	/* empty default implementation */
}

- (void)dealloc
{
	[_completionsSoFar release];

	[super dealloc];
}

@end
