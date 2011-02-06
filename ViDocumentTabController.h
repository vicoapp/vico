@class ViDocument;
@class ViDocumentView;

typedef enum ViViewOrderingMode ViViewOrderingMode;
enum ViViewOrderingMode {
	ViViewNone,
	ViViewLeft,
	ViViewDown,
	ViViewUp,
	ViViewRight
};

@interface ViDocumentTabController : NSObject
{
	NSSplitView	*splitView;
	NSMutableArray	*views;
	ViDocumentView	*selectedDocumentView;
}

@property(readonly) NSArray *views;
@property(readwrite, assign) ViDocumentView *selectedDocumentView;

- (id)initWithDocumentView:(ViDocumentView *)initialDocumentView;
- (void)addView:(ViDocumentView *)docView;
- (NSView *)view;
- (ViDocumentView *)splitView:(ViDocumentView *)docView vertically:(BOOL)isVertical;
- (ViDocumentView *)replaceDocumentView:(ViDocumentView *)docView withDocument:(ViDocument *)document;
- (void)closeDocumentView:(ViDocumentView *)docView;
- (NSSet *)documents;
- (ViDocumentView *)viewAtPosition:(ViViewOrderingMode)position relativeTo:(NSView *)aDocView;

@end

