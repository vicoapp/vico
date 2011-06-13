#import "ViPreferencePane.h"
#import "ViScope.h"

@interface ViPreferencePaneEdit : ViPreferencePane
{
	IBOutlet NSWindow *newPrefScopeSheet;
	IBOutlet NSPopUpButton *prefLanguage;
	IBOutlet NSTextField *prefScope;
	IBOutlet NSPopUpButton *scopeButton;
	IBOutlet NSButton *revertButton;
	IBOutlet NSButton *newScopeButton;

	NSMutableSet *preferences;
}

+ (id)valueForKey:(NSString *)key inScope:(ViScope *)scope;

- (IBAction)selectScope:(id)sender;
- (IBAction)selectNewPreferenceScope:(id)sender;
- (IBAction)cancelNewPreferenceScope:(id)sender;
- (IBAction)acceptNewPreferenceScope:(id)sender;
- (IBAction)selectPrefLanguage:(id)sender;
- (IBAction)revertPreferenceScope:(id)sender;

@end

