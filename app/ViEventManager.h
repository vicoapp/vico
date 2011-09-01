#import "Nu/Nu.h"

// Document Controller events
#define ViEventDidFinishLaunching @"didFinishLaunching" // nil
#define ViEventWillResignActive @"willResignActive" // nil
#define ViEventDidBecomeActive @"didBecomeActive" // nil
#define ViEventDidAddDocument @"didAddDocument" // doc
#define ViEventDidRemoveDocument @"didRemoveDocument" // doc

// Document events
#define ViEventWillChangeURL @"willChangeURL" // doc, url
#define ViEventDidChangeURL @"didChangeURL" // doc, url
#define ViEventWillLoadDocument @"willLoadDocument" // doc, url
#define ViEventDidLoadDocument @"didLoadDocument" // doc
#define ViEventWillSaveDocument @"willSaveDocument" // doc
#define ViEventWillSaveAsDocument @"willSaveAsDocument" // doc, url
#define ViEventDidSaveDocument @"didSaveDocument" // doc
#define ViEventDidSaveAsDocument @"didSaveAsDocument" // doc, url
#define ViEventWillCloseDocument @"willCloseDocument" // doc
#define ViEventDidCloseDocument @"didCloseDocument" // doc
#define ViEventDidModifyDocument @"didModifyDocument" // doc, range, delta
#define ViEventDidMakeView @"didMakeView" // doc, view, text
#define ViEventWillChangeSyntax @"willChangeSyntax" // doc, (new) language
#define ViEventDidChangeSyntax @"didChangeSyntax" // doc, (new) language

// Text events
#define ViEventCaretDidMove @"caretDidMove" // text

// Window events
#define ViEventWillSelectDocument @"willSelectDocument" // window, doc
#define ViEventDidSelectDocument @"didSelectDocument" // window, doc
#define ViEventWillSelectView @"willSelectView" // window, view
#define ViEventDidSelectView @"didSelectView" // window, view
#define ViEventWillSelectTab @"willSelectTab" // window, tabController
#define ViEventDidSelectTab @"didSelectTab" // window, tabController
#define ViEventWillEnterFullScreen  @"willEnterFullScreen" // window
#define ViEventDidEnterFullScreen  @"didEnterFullScreen" // window
#define ViEventWillExitFullScreen  @"willExitFullScreen" // window
#define ViEventDidExitFullScreen  @"didExitFullScreen" // window

// Tabcontroller events
#define ViEventDidAddView @"didAddView" // view
#define ViEventDidCloseView @"didCloseView" // view

// Other events
#define ViEventDirectoryChanged @"directoryChanged" // url
#define ViEventExplorerDirectoryChanged @"explorerDirectoryChanged" // explorer, url
#define ViEventExplorerURLUpdated @"explorerURLUpdated" // explorer, url
#define ViEventExplorerRootChanged @"explorerRootChanged" // explorer, url

@interface ViEvent : NSObject
{
	NuBlock *expression;
	NSInteger eventId;
}
- (id)initWithExpression:(NuBlock *)anExpression;
@property (nonatomic,readonly) NuBlock *expression;
@property (nonatomic,readonly) NSInteger eventId;
@end

/** The event manager is used to automatically run code when specific
 * events occur. An event handler is defined as a Nu function, typically
 * an anonymous function created with the Nu `do` operator. An event
 * handler will receive zero or more arguments, depending on the event.
 * Any return value is ignored.
 *
 * The standard events are described below.
 *
 * ## Constants
 *
 * ### Standard event names
 *
 * #### Document Controller events
 *
 * <dl class="termdef">
 * <dt><code>didFinishLaunching</code></dt>
 * <dd>
 *  <p>Emitted when Vico has finished launching.</p>
 *  <p>arguments: <em>none</em></p>
 * </dd>
 *
 * <dt><code>willResignActive</code></dt>
 * <dd>
 *  <p>Emitted when Vico resigns active state (ie, loses focus).</p>
 *  <p>arguments: <em>none</em></p>
 * </dd>
 *
 * <dt><code>didBecomeActive</code></dt>
 * <dd>
 *  <p>Emitted when Vico becomes active (ie, regains focus).</p>
 *  <p>arguments: <em>none</em></p>
 * </dd>
 *
 * <dt><code>didAddDocument</code></dt>
 * <dd>
 *  <p>Emitted when a new document is opened.</p>
 *  <p>arguments: <em>document</em></p>
 * </dd>
 *
 * <dt><code>didRemoveDocument</code></dt>
 * <dd>
 *  <p>Emitted when a document is closed.</p>
 *  <p>arguments: <em>document</em></p>
 * </dd>
 * </dl>
 *
 * #### Document events
 *
 * <dl class="termdef">
 * <dt><code>willChangeURL</code></dt>
 * <dd>
 *  <p>Emitted before a document changes it's URL.</p>
 *  <p>arguments: <em>document, url</em></p>
 * </dd>
 *
 * <dt><code>didChangeURL</code></dt>
 * <dd>
 *  <p>Emitted after a document changed it's URL.</p>
 *  <p>arguments: <em>document, url</em></p>
 * </dd>
 *
 * <dt><code>willLoadDocument</code></dt>
 * <dd>
 *  <p>Emitted before a document is loaded.</p>
 *  <p>arguments: <em>document, url</em></p>
 * </dd>
 *
 * <dt><code>didLoadDocument</code></dt>
 * <dd>
 *  <p>Emitted after a document was loaded.</p>
 *  <p>arguments: <em>document</em></p>
 * </dd>
 *
 * <dt><code>willSaveDocument</code></dt>
 * <dd>
 *  <p>Emitted before a document is being saved.</p>
 *  <p>arguments: <em>document</em></p>
 * </dd>
 *
 * <dt><code>didSaveDocument</code></dt>
 * <dd>
 *  <p>Emitted after a document was saved.</p>
 *  <p>arguments: <em>document</em></p>
 * </dd>
 *
 * <dt><code>willSaveAsDocument</code></dt>
 * <dd>
 *  <p>Emitted before a document is being saved at a new URL.</p>
 *  <p>arguments: <em>document, url</em></p>
 * </dd>
 *
 * <dt><code>didSaveAsDocument</code></dt>
 * <dd>
 *  <p>Emitted after a document was saved at a new URL.</p>
 *  <p>arguments: <em>document, url</em></p>
 * </dd>
 *
 * <dt><code>willCloseDocument</code></dt>
 * <dd>
 *  <p>Emitted before a document is closed.</p>
 *  <p>arguments: <em>document</em></p>
 * </dd>
 *
 * <dt><code>didCloseDocument</code></dt>
 * <dd>
 *  <p>Emitted after a document was closed.</p>
 *  <p>arguments: <em>document</em></p>
 * </dd>
 *
 * <dt><code>didModifyDocument</code></dt>
 * <dd>
 *  <p>Emitted after a document was modified.</p>
 *  <p>arguments: <em>document, range, delta</em></p>
 * </dd>
 *
 * <dt><code>didMakeView</code></dt>
 * <dd>
 *  <p>Emitted after a new document view was created.</p>
 *  <p>arguments: <em>document, view, text</em></p>
 * </dd>
 *
 * <dt><code>willChangeSyntax</code></dt>
 * <dd>
 *  <p>Emitted before a document changes language syntax.</p>
 *  <p>arguments: <em>document, language</em></p>
 * </dd>
 *
 * <dt><code>didChangeSyntax</code></dt>
 * <dd>
 *  <p>Emitted after a document changed language syntax.</p>
 *  <p>arguments: <em>document, language</em></p>
 * </dd>
 * </dl>
 *
 * #### Text events
 *
 * <dl class="termdef">
 * <dt><code>caretDidMove</code></dt>
 * <dd>
 *  <p>Emitted after the caret has changed in a text view.</p>
 *  <p>arguments: <em>text</em></p>
 * </dd>
 * </dl>
 *
 * #### Window events
 *
 * <dl class="termdef">
 * <dt><code>willSelectDocument</code></dt>
 * <dd>
 *  <p>Emitted before the selected document is changed in a window.</p>
 *  <p>arguments: <em>window, document</em></p>
 * </dd>
 *
 * <dt><code>didSelectDocument</code></dt>
 * <dd>
 *  <p>Emitted after the selected document was changed in a window.</p>
 *  <p>arguments: <em>window, document</em></p>
 * </dd>
 *
 * <dt><code>willSelectView</code></dt>
 * <dd>
 *  <p>Emitted before the selected view is changed in a window.</p>
 *  <p>arguments: <em>window, view</em></p>
 * </dd>
 *
 * <dt><code>didSelectView</code></dt>
 * <dd>
 *  <p>Emitted after the selected view was changed in a window.</p>
 *  <p>arguments: <em>window, view</em></p>
 * </dd>
 *
 * <dt><code>willSelectTab</code></dt>
 * <dd>
 *  <p>Emitted before the selected tab is changed in a window.</p>
 *  <p>arguments: <em>window, tab controller</em></p>
 * </dd>
 *
 * <dt><code>didSelectTab</code></dt>
 * <dd>
 *  <p>Emitted after the selected tab was changed in a window.</p>
 *  <p>arguments: <em>window, tab controller</em></p>
 * </dd>
 * </dl>
 *
 * #### Tab Controller events
 *
 * <dl class="termdef">
 * <dt><code>didAddView</code></dt>
 * <dd>
 *  <p>Emitted after a view was added to a tab.</p>
 *  <p>arguments: <em>view</em></p>
 * </dd>
 *
 * <dt><code>didCloseView</code></dt>
 * <dd>
 *  <p>Emitted after a view was removed from a tab.</p>
 *  <p>arguments: <em>view</em></p>
 * </dd>
 * </dl>
 */
@interface ViEventManager : NSObject
{
	// keys are event names (strings)
	NSMutableDictionary *_anonymous_events;	// values are NSMutableArrays of ViEvents
	NSMutableDictionary *_owned_events;	// values are NSMapTables, map keys are owner objects, values are NSMutableArrays of ViEvents
}

/**
 * @returns The default global event manager.
 */
+ (ViEventManager *)defaultManager;

/** @name Emitting events */

- (void)emit:(NSString *)event for:(id)owner with:(id)arg1, ...;

/** Emit an event immediately.
 *
 * You should not manually emit any of the standard events.
 *
 * @param event The name of the event; cannot be `nil`.
 * @param owner The object that is responsible for emitting the event.
 * @param arguments The arguments to the event handler. Can either be an NSArray or a Nu list.
 */
- (void)emit:(NSString *)event for:(id)owner withArguments:(id)arguments;

/** Emit an event in the next run loop iteration.
 *
 * You should not manually emit any of the standard events.
 *
 * @param event The name of the event; cannot be `nil`.
 * @param owner The object that is responsible for emitting the event.
 * @param arguments The arguments to the event handler. Can either be an NSArray or a Nu list.
 */
- (void)emitDelayed:(NSString *)event for:(id)owner withArguments:(id)arguments;

- (void)emitDelayed:(NSString *)event for:(id)owner with:(id)arg1, ...;

/** @name Registering event handlers */

/** Register a handler for an event by a specific object.
 *
 * This event handler is called whenever the `event` is emitted by the
 * `owner` object.
 *
 * @param event The name of the event; cannot be `nil`.
 * @param owner The object that emitted the event.
 * @param expression A Nu anonymous function (`do` block). See the [Nu documentation](http://programming.nu/operators#functions).
 * The number of arguments to the function must match the number of arguments emitted.
 * @returns A unique event ID.
 * @see remove:
 */
- (NSInteger)on:(NSString *)event by:(id)owner do:(NuBlock *)expression;

/** Register an event handler.
 *
 * This event handler is called whenever the `event` is emitted,
 * regardless of the emitting object.
 *
 * @param event The name of the event; cannot be `nil`.
 * @param expression A Nu anonymous function (`do` block). See the [Nu documentation](http://programming.nu/operators#functions).
 * The number of arguments to the function must match the number of arguments emitted.
 * @returns A unique event ID.
 * @see on:by:do:
 * @see remove:
 */
- (NSInteger)on:(NSString *)event do:(NuBlock *)expression;

/** @name Removing event handlers */

/** Remove all events handlers for a specific object.
 *
 * @param event The name of the event; cannot be `nil`.
 * @param owner The object that is responsible for emitting the event.
 */
- (void)clear:(NSString *)event for:(id)owner;

/** Remove all handlers for an event.
 *
 * @param event The name of the event; cannot be `nil`.
 */
- (void)clear:(NSString *)event;

/** Remove all handlers for an object.
 *
 * @param owner The object that is responsible for emitting the event.
 */
- (void)clearFor:(id)owner;

/** Remove all handlers for all events.
 */
- (void)clear;

/** Remove an event handler.
 * @param eventId An event ID as returned by on:by:do:.
 */
- (void)remove:(NSInteger)eventId;

@end
