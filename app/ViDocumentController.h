@class ViDocument;

@interface ViDocumentController : NSDocumentController
{
	id			 _closeAllDelegate;
	SEL			 _closeAllSelector;
	void			*_closeAllContextInfo;
	BOOL			 _closeAllWindows;
	NSMutableSet		*_closeAllSet;
	NSMutableDictionary	*_openDocs;
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
