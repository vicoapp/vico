@interface ViDocumentController : NSDocumentController
{
	id		 closeAllDelegate;
	SEL		 closeAllSelector;
	void		*closeAllContextInfo;
	BOOL		 closeAllWindows;
	NSMutableSet	*closeAllSet;
}

- (IBAction)closeCurrentDocument:(id)sender;

- (void)closeAllDocumentsInSet:(NSMutableSet *)set
		  withDelegate:(id)delegate
	   didCloseAllSelector:(SEL)didCloseAllSelector
		   contextInfo:(void *)contextInfo;

@end
