@class ViDocument;
@class ViTabController;
@class ViViewController;
@class ViDocumentView;

typedef enum ViViewPosition ViViewPosition;
typedef enum ViViewOrderingMode ViViewOrderingMode;

enum ViViewPosition {
	ViViewPositionDefault = 0,
	ViViewPositionPreferred,
	ViViewPositionReplace,
	ViViewPositionTab,
	ViViewPositionSplitLeft,
	ViViewPositionSplitVertical = ViViewPositionSplitLeft,
	ViViewPositionSplitRight,
	ViViewPositionSplitAbove,
	ViViewPositionSplitHorizontal = ViViewPositionSplitAbove,
	ViViewPositionSplitBelow
};

/** Ordering of views. */
enum ViViewOrderingMode {
	ViViewNone,
	ViViewLeft,
	ViViewDown,
	ViViewUp,
	ViViewRight,
	ViViewLast
};



/** A document which can have multiple views.
 */
@protocol ViViewDocument <NSObject>
/** Add a view to the set of visible views.
 * @param viewController The view to add.
 */
- (void)addView:(ViViewController *)viewController;

/** Remove a view from the set of visible views.
 * @param viewController The view to remove.
 */
- (void)removeView:(ViViewController *)viewController;

/** Create a new view of the document.
 * @returns The newly created view of the document.
 */
- (ViViewController *)makeView;

/** Create a new view of the document by cloning an existing view.
 *
 * The new view is expected to inherit properties from the cloned view, such as caret location.
 * @param oldView The view that is being cloned.
 * @returns The newly created view of the document.
 */
- (ViViewController *)cloneView:(ViViewController *)oldView;

/**
 * @returns The set of visible views of the document.
 */
- (NSSet *)views;

/**
 * @returns YES if the document is modified, otherwise NO.
 */
- (BOOL)isDocumentEdited;
@end




/** A controller of a tab.
 */
@interface ViTabController : NSObject
{
	NSSplitView		*_splitView;
	NSMutableArray		*_views;
	NSWindow		*_window;
	ViViewController	*_selectedView;
	ViViewController	*_previousView;
}

@property(nonatomic,readonly) NSArray *views;
/** The window this tab belongs to. */
@property(nonatomic,readonly) NSWindow *window;
@property(nonatomic,readwrite,retain) ViViewController *selectedView;
@property(nonatomic,readwrite,retain) ViViewController *previousView;

- (id)initWithViewController:(ViViewController *)initialViewController
		      window:(NSWindow *)aWindow;
- (void)addView:(ViViewController *)aView;
- (NSView *)view;

/** @name Splitting views */

/** Splits a view and displays another view.
 * @param viewController The view that should be split.
 * @param newViewController The view that should be displayed.
 * @param isVertical YES if the split is vertical, NO if horizontal.
 * @returns newViewController or `nil` on failure.
 */
- (ViViewController *)splitView:(ViViewController *)viewController
		       withView:(ViViewController *)newViewController
		     vertically:(BOOL)isVertical;

/** Splits a view and displays another view.
 * @param viewController The view that should be split.
 * @param newViewController The view that should be displayed.
 * @param position The position of the split (left, right, above or below)
 * @returns newViewController or `nil` on failure.
 */
- (ViViewController *)splitView:(ViViewController *)viewController
		       withView:(ViViewController *)newViewController
		     positioned:(ViViewPosition)position;

/** Splits a view and displays a clone of the view.
 *
 * The view controller must have an associated document that can clone views.
 *
 * @param viewController The view that should be split.
 * @param isVertical YES if the split is vertical, NO if horizontal.
 * @returns The new view controller or `nil` on failure.
 */
- (ViViewController *)splitView:(ViViewController *)viewController
		     vertically:(BOOL)isVertical;

- (ViViewController *)replaceView:(ViViewController *)viewController
			 withView:(ViViewController *)newViewController;

- (void)closeView:(ViViewController *)viewController;

- (void)closeViewsOtherThan:(ViViewController *)viewController;

- (NSSet *)representedObjectsOfClass:(Class)class matchingCriteria:(BOOL (^)(id))block;
- (NSSet *)documents;

- (ViViewController *)viewOfClass:(Class)class withRepresentedObject:(id)repObj;
- (ViDocumentView *)viewWithDocument:(ViDocument *)document;

- (ViViewController *)viewAtPosition:(ViViewOrderingMode)position
			  relativeTo:(NSView *)aView;

- (ViViewController *)nextViewClockwise:(BOOL)clockwise
			     relativeTo:(NSView *)view;
- (ViViewController *)viewControllerForView:(NSView *)aView;
- (void)normalizeAllViews;

@end

