#import <Cocoa/Cocoa.h>

@interface ViDocumentController : NSDocumentController
{
	id	 closeAllDelegate;
	SEL	 closeAllSelector;
	void	*closeAllContextInfo;
	BOOL	 closeAllWindows;
}

- (IBAction)closeCurrentDocument:(id)sender;

- (void)closeAllDocumentsInWindow:(NSWindow *)window
		     withDelegate:(id)delegate
	      didCloseAllSelector:(SEL)didCloseAllSelector;

@end
