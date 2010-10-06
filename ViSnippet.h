#import <Cocoa/Cocoa.h>

@class ViSnippetPlaceholder;


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
@property(readwrite, assign) ViSnippetPlaceholder *currentPlaceholder;
@property(readwrite, assign) ViSnippetPlaceholder *lastPlaceholder;
@property(readonly) NSArray *tabstops;
@property(readonly, copy) NSString *string;
@property(readonly) NSRange range;

- (ViSnippet *)initWithString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (BOOL)activeInRange:(NSRange)aRange;
- (void)updateLength:(NSInteger)aLength fromLocation:(NSUInteger)aLocation;
- (BOOL)done;

@end


@interface ViSnippetPlaceholder : NSObject
{
	NSString *string;
	NSString *value;
	unsigned length;
	int tabStop;
	BOOL selected;
	NSRange range;
	NSString *variable;
	NSString *defaultValue;
	NSString *transformation; // regexp string
}

@property (readonly) unsigned length;
@property (readonly) int tabStop;
@property (readwrite) BOOL selected;
@property(readwrite) NSRange range;
@property (readonly) NSString *variable;
@property (readonly) NSString *defaultValue;
@property (readonly) NSString *transformation;
@property (readonly) NSString *value;

- (ViSnippetPlaceholder *)initWithString:(NSString *)s;
- (void)updateLength:(NSInteger)aLength fromLocation:(NSUInteger)aLocation;
- (BOOL)activeInRange:(NSRange)aRange;
- (NSInteger)updateValue:(NSString *)newValue;

@end
