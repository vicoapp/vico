#import "ViTabController.h"

/** A ViViewController manages a split view in Vico.
 * @see ViDocumentView.
 */
@interface ViViewController : NSViewController
{
	ViTabController	*_tabController;
	BOOL		 _modified;
	BOOL		 _processing;
}

/** The ViTabController this view belongs to. */
@property (nonatomic,readwrite,assign) ViTabController *tabController;

/** The inner NSView will be made key when the view gets focus. */
@property (nonatomic,readonly) NSView *innerView;

/** YES if the view represents a modified object.
 * When this is YES, a different close button is displayed in the tab bar.
 */
@property (nonatomic,readwrite) BOOL modified;

/** YES if the view represents an object that is busy processing a command.
 * When this is YES, a spinner is displayed in the tab bar.
 */
@property (nonatomic,readwrite) BOOL processing;

- (void)attach;
- (void)detach;

@end
