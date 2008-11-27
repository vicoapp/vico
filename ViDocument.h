#import <Cocoa/Cocoa.h>
#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"

@class NoodleLineNumberView;

@interface ViDocument : NSDocument
{
	IBOutlet NSView *view;
	IBOutlet NSScrollView *scrollView;
	IBOutlet ViTextView *textView;
	NoodleLineNumberView *lineNumberView;
	IBOutlet NSTextField *statusbar;
	IBOutlet NSPopUpButton *languageButton;
	SEL exCommandSelector;
	ViWindowController *windowController;
	NSString *readContent;
	NSArray *symbols;
}

@property(readonly) NSScrollView *scrollView;
@property(readwrite, assign) NSArray *symbols;

- (NSView *)view;
- (void)enableLineNumbers:(BOOL)flag;
- (IBAction)toggleLineNumbers:(id)sender;
- (IBAction)finishedExCommand:(id)sender;
- (IBAction)setLanguage:(id)sender;
- (void)message:(NSString *)fmt, ...;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector prompt:(NSString *)aPrompt;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector;
- (void)changeTheme:(ViTheme *)theme;
- (void)setPageGuide:(int)pageGuideValue;
- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax;
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn;
- (void)popTag;
- (ViTextView *)textView;
- (void)goToSymbol:(ViSymbol *)aSymbol;

@end
