#import "ViCompletionController.h"

@interface ViGCDAsyncCompletionProvider : NSObject <ViCompletionProvider, ViAsyncCompletionProvider>
{
	NSMutableArray *_completionsSoFar;
	id<ViCompletionReceiver> _completionReceiver;
}

/**
 * This will always return an empty array, and invoke startCompleting in
 * the appropriate GCD queue. It kicks off the completion process, but
 * lets it happen in the background.
 */
- (NSArray *)completionsForString:(NSString *)string
						  options:(NSString *)options
							error:(NSError **)outError;

/**
 * Call this to set the completion receiver, which will be notified when
 * completions are received. If there are already available completions,
 * the completion receiver will be notified immediately. If there are none,
 * the receiver will be notified when they come in.
 *
 * This is expected to be called from the global main queue (i.e., from the
 * application runloop).
 */
- (void)setCompletionReceiver:(id<ViCompletionReceiver>)completionReceiver;
/**
 * Call this when completions are received (all or some; these are added
 * to the list of completions so far). The completions will be reported to
 * the receiver set by setCompletionReceiver: on the main queue, or they
 * will be stored to report to the completion receiver when it is
 * provided.
 *
 * This is expected to be called from the default priority global queue.
 */
- (void)completionsReceived:(NSArray *)completions;
/**
 * Override this in your implementation. This will be called in the
 * default priority global GCD queue, and can block at will. When
 * completions are received, call completionsReceived:, which will
 * provide the completions to the receiver on the main queue.
 */
- (void)startCompleting;

@end
