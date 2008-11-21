#import <Cocoa/Cocoa.h>

@interface ViSnippetPlaceholder : NSObject
{
	NSString *string;
	unsigned length;
	int tabStop;
	NSRange range;
	NSString *variable;
	NSString *defaultValue;
	NSString *transformation; // regexp string
}

@property (readonly) unsigned length;
@property (readonly) int tabStop;
@property(readwrite) NSRange range;
@property (readonly) NSString *variable;
@property (readonly) NSString *defaultValue;
@property (readonly) NSString *transformation;

- (ViSnippetPlaceholder *)initWithString:(NSString *)s;
- (void)pushLength:(int)length ifAffectedByRange:(NSRange)affectedRange;

@end


@interface ViSnippet : NSObject
{
	int currentTab;
	NSString *string;
	NSRange range;
	NSMutableArray *tabstops;
	ViSnippetPlaceholder *currentPlaceholder;
	ViSnippetPlaceholder *lastPlaceholder;
}

@property(readwrite) int currentTab;
@property(readwrite) ViSnippetPlaceholder *currentPlaceholder;
@property(readwrite) ViSnippetPlaceholder *lastPlaceholder;
@property(readonly) NSArray *tabstops;
@property(readonly) NSString *string;
@property(readonly) NSRange range;

- (ViSnippet *)initWithString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (BOOL)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (BOOL)deleteRange:(NSRange)affectedRange;

@end
