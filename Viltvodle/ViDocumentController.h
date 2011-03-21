@class ViDocument;

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

- (NSURL *)normalizePath:(NSString *)filename
              relativeTo:(NSURL *)relURL
                   error:(NSError **)outError;
- (ViDocument *)openDocument:(id)filenameOrURL
                  andDisplay:(BOOL)display
              allowDirectory:(BOOL)allowDirectory;
- (ViDocument *)splitVertically:(BOOL)isVertical
                        andOpen:(id)filenameOrURL
             orSwitchToDocument:(ViDocument *)doc;

@end
