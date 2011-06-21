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

// Tabcontroller events
#define ViEventDidAddView @"didAddView" // view
#define ViEventDidCloseView @"didCloseView" // view

@interface ViEvent : NSObject
{
	id owner;
	NuBlock *expression;
	NSInteger eventId;
}
- (id)initWithExpression:(NuBlock *)anExpression owner:(id)anOwner;
@property (nonatomic,readonly) id owner;
@property (nonatomic,readonly) NuBlock *expression;
@property (nonatomic,readonly) NSInteger eventId;
@end

@interface ViEventManager : NSObject
{
	NSMutableDictionary *_events;
}

+ (ViEventManager *)defaultManager;

- (void)emit:(NSString *)event for:(id)owner with:(id)arg1, ...;
- (void)emit:(NSString *)event for:(id)owner withArguments:(id)arguments;

- (void)emitDelayed:(NSString *)event for:(id)owner withArguments:(id)arguments;
- (void)emitDelayed:(NSString *)event for:(id)owner with:(id)arg1, ...;

- (NSInteger)on:(NSString *)event by:(id)owner do:(NuBlock *)expression;
- (NSInteger)on:(NSString *)event do:(NuBlock *)expression;

- (void)clear:(NSString *)event for:(id)owner;
- (void)clear:(NSString *)event;
- (void)clearFor:(id)owner;
- (void)clear;

- (void)remove:(NSInteger)eventId;

@end
