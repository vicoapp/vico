/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

@class ViDocument;
@class ViDocumentView;
@class ViTabController;
@class ViTextView;
@class ViViewController;

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
@property(nonatomic,readwrite,strong) ViViewController *selectedView;
@property(nonatomic,readwrite,strong) ViViewController *previousView;

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

- (void)detachView:(ViViewController *)viewController;
- (void)closeView:(ViViewController *)viewController;

- (void)closeViewsOtherThan:(ViViewController *)viewController;

- (NSSet *)representedObjectsOfClass:(Class)class matchingCriteria:(BOOL (^)(id))block;
- (NSSet *)documents;

- (ViViewController *)viewOfClass:(Class)class withRepresentedObject:(id)repObj;
- (ViDocumentView *)viewWithDocument:(ViDocument *)document;
- (ViDocumentView *)viewWithTextView:(ViTextView *)aTextView;

- (ViViewController *)viewAtPosition:(ViViewOrderingMode)position
			  relativeTo:(NSView *)aView;

- (ViViewController *)nextViewClockwise:(BOOL)clockwise
			     relativeTo:(NSView *)view;
- (ViViewController *)viewControllerForView:(NSView *)aView;
- (void)normalizeAllViews;

@end

