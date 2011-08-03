@class ViDocument;
@class ViDocumentTabController;

typedef enum ViViewOrderingMode ViViewOrderingMode;

/** Ordering of views. */
enum ViViewOrderingMode {
	ViViewNone,
	ViViewLeft,
	ViViewDown,
	ViViewUp,
	ViViewRight,
	ViViewLast
};

@protocol ViViewDocument;

/** Controller object wrapping a split view.
 */
@protocol ViViewController <NSObject>
/** The NSView that should be displayed in the split. */
@property(nonatomic,readonly) NSView *view;
/** The inner NSView will be made key when the view gets focus. */
@property(nonatomic,readonly) NSView *innerView;
/** The containing tab controller. */
@property(nonatomic,readwrite, assign) ViDocumentTabController *tabController;
/** The title of the split view. */
- (NSString *)title;
@optional
/** The document that is being displayed, if available. */
- (id<ViViewDocument>)document;
@end

/** A document which can have multiple views.
 */
@protocol ViViewDocument <NSObject>
/** Add a view to the set of visible views.
 * @param viewController The view to add.
 */
- (void)addView:(id<ViViewController>)viewController;

/** Remove a view from the set of visible views.
 * @param viewController The view to remove.
 */
- (void)removeView:(id<ViViewController>)viewController;

/** Create a new view of the document.
 * @returns The newly created view of the document.
 */
- (id<ViViewController>)makeView;

/** Create a new view of the document by cloning an existing view.
 *
 * The new view is expected to inherit properties from the cloned view, such as caret location.
 * @param oldView The view that is being cloned.
 * @returns The newly created view of the document.
 */
- (id<ViViewController>)cloneView:(id<ViViewController>)oldView;

/**
 * @returns The set of visible views of the document.
 */
- (NSSet *)views;

/**
 * @returns YES if the document is modified, otherwise NO.
 */
- (BOOL)isDocumentEdited;
@end

/*? A controller of a tab.
 */
@interface ViDocumentTabController : NSObject
{
	NSSplitView		*splitView;
	NSMutableArray		*views;
	NSWindow		*window;
	id<ViViewController>	 selectedView;
	id<ViViewController>	 previousView;
}

@property(nonatomic,readonly) NSArray *views;
/*? The window this tab belongs to. */
@property(nonatomic,readonly) NSWindow *window;
@property(nonatomic,readwrite, assign) id<ViViewController> selectedView;
@property(nonatomic,readwrite, assign) id<ViViewController> previousView;

- (id)initWithViewController:(id<ViViewController>)initialViewController
		      window:(NSWindow *)aWindow;
- (void)addView:(id<ViViewController>)aView;
- (NSView *)view;

/*? @name Splitting views */

/*? Splits a view and displays another view.
 * @param viewController The view that should be split.
 * @param newViewController The view that should be displayed.
 * @param isVertical YES if the split is vertical, NO if horizontal.
 * @returns newViewController or nil on failure.
 */
- (id<ViViewController>)splitView:(id<ViViewController>)viewController
                         withView:(id<ViViewController>)newViewController
                       vertically:(BOOL)isVertical;

/*? Splits a view and displays a clone of the view.
 *
 * The view controller must have an associated document that can clone views.
 *
 * @param viewController The view that should be split.
 * @param isVertical YES if the split is vertical, NO if horizontal.
 * @returns The new view controller or nil on failure.
 */
- (id<ViViewController>)splitView:(id<ViViewController>)viewController
                       vertically:(BOOL)isVertical;

- (id<ViViewController>)replaceView:(id<ViViewController>)aView
                       withDocument:(ViDocument *)document;

- (void)closeView:(id<ViViewController>)viewController;

- (void)closeViewsOtherThan:(id<ViViewController>)viewController;
- (NSSet *)documents;

- (id<ViViewController>)viewAtPosition:(ViViewOrderingMode)position
                            relativeTo:(NSView *)aView;

- (id<ViViewController>)nextViewClockwise:(BOOL)clockwise
			       relativeTo:(NSView *)view;
- (id<ViViewController>)viewControllerForView:(NSView *)aView;
- (void)normalizeAllViews;

@end

