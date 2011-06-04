@class ViDocument;
@class ViDocumentTabController;

typedef enum ViViewOrderingMode ViViewOrderingMode;
enum ViViewOrderingMode {
	ViViewNone,
	ViViewLeft,
	ViViewDown,
	ViViewUp,
	ViViewRight
};

@protocol ViViewController <NSObject>
@property(readwrite, assign) NSWindow *window;
@property(readonly) NSView *view;
@property(readonly) NSView *innerView;
@property(readwrite, assign) ViDocumentTabController *tabController;
- (NSString *)title;
@end

@interface NSObject (ViDocumentProtocol)
- (void)removeView:(id<ViViewController>)viewController;
- (id<ViViewController>)makeView;
@end

@interface ViDocumentTabController : NSObject
{
	NSSplitView		*splitView;
	NSMutableArray		*views;
	id<ViViewController>	 selectedView;
	id<ViViewController>	 previousView;
}

@property(readonly) NSArray *views;
@property(readwrite, assign) id<ViViewController> selectedView;
@property(readwrite, assign) id<ViViewController> previousView;

- (id)initWithViewController:(id<ViViewController>)initialView;
- (void)addView:(id<ViViewController>)aView;
- (NSView *)view;
- (id<ViViewController>)splitView:(id<ViViewController>)viewController withView:(id<ViViewController>)newViewController vertically:(BOOL)isVertical;
- (id<ViViewController>)splitView:(id<ViViewController>)aView vertically:(BOOL)isVertical;
- (id<ViViewController>)replaceView:(id<ViViewController>)aView withDocument:(ViDocument *)document;
- (void)closeView:(id<ViViewController>)aView;
- (void)closeViewsOtherThan:(id<ViViewController>)viewController;
- (NSSet *)documents;
//- (NSSet *)documentsOfType:(Class)class;
- (id<ViViewController>)viewAtPosition:(ViViewOrderingMode)position relativeTo:(NSView *)aView;
- (id<ViViewController>)viewControllerForView:(NSView *)aView;
- (void)normalizeAllViews;

@end

