@class ViDocument;

@interface ViDocumentController : NSDocumentController
{
	id		 closeAllDelegate;
	SEL		 closeAllSelector;
	void		*closeAllContextInfo;
	BOOL		 closeAllWindows;
	NSMutableSet	*closeAllSet;
	NSMutableDictionary *openDocs;
}

- (void)updateURL:(NSURL *)aURL ofDocument:(NSDocument *)aDocument;
- (id)documentForURLQuick:(NSURL *)absoluteURL;

- (void)closeAllDocumentsInSet:(NSMutableSet *)set
		  withDelegate:(id)delegate
	   didCloseAllSelector:(SEL)didCloseAllSelector
		   contextInfo:(void *)contextInfo;

- (NSURL *)normalizePath:(NSString *)filename
              relativeTo:(NSURL *)relURL
                   error:(NSError **)outError;

@end
