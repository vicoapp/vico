@class ViDocument;
@class ViDocumentTabController;

typedef enum ViViewOrderingMode ViViewOrderingMode;
enum ViViewOrderingMode {
	ViViewNone,
	ViViewLeft,
	ViViewDown,
	ViViewUp,
	ViViewRight,
	ViViewLast
};

@protocol ViViewDocument;

@protocol ViViewController <NSObject>
@property(nonatomic,readonly) NSView *view;
@property(nonatomic,readonly) NSView *innerView;
@property(nonatomic,readwrite, assign) ViDocumentTabController *tabController;
- (NSString *)title;
@optional
- (id<ViViewDocument>)document;
@end

@protocol ViViewDocument <NSObject>
- (void)addView:(id<ViViewController>)viewController;
- (void)removeView:(id<ViViewController>)viewController;
- (id<ViViewController>)makeView;
- (id<ViViewController>)cloneView:(id<ViViewController>)oldView;
- (NSSet *)views;
- (BOOL)isDocumentEdited;
@end

@interface ViDocumentTabController : NSObject
{
	NSSplitView		*splitView;
	NSMutableArray		*views;
	id<ViViewController>	 selectedView;
	id<ViViewController>	 previousView;
}

@property(nonatomic,readonly) NSArray *views;
@property(nonatomic,readwrite, assign) id<ViViewController> selectedView;
@property(nonatomic,readwrite, assign) id<ViViewController> previousView;

- (id)initWithViewController:(id<ViViewController>)initialView;
- (void)addView:(id<ViViewController>)aView;
- (NSView *)view;
- (id<ViViewController>)splitView:(id<ViViewController>)viewController
                         withView:(id<ViViewController>)newViewController
                       vertically:(BOOL)isVertical;
- (id<ViViewController>)splitView:(id<ViViewController>)aView
                       vertically:(BOOL)isVertical;
- (id<ViViewController>)replaceView:(id<ViViewController>)aView
                       withDocument:(ViDocument*)document;
- (void)closeView:(id<ViViewController>)aView;
- (void)closeViewsOtherThan:(id<ViViewController>)viewController;
- (NSSet *)documents;
- (id<ViViewController>)viewAtPosition:(ViViewOrderingMode)position
                            relativeTo:(NSView *)aView;
- (id<ViViewController>)nextViewClockwise:(BOOL)clockwise
			       relativeTo:(NSView *)view;
- (id<ViViewController>)viewControllerForView:(NSView *)aView;
- (void)normalizeAllViews;

@end

