@class ViDocument;
@class ViMarkList;

/** A marked location.
 */
@interface ViMark : NSObject
{
	NSString *name;
	NSUInteger location;
	NSRange range;
	NSUInteger line, column;

	NSNumber *lineNumber;
	NSNumber *columnNumber;

	id title;
	NSImage *icon;

	NSString *groupName;
	NSURL *url;
	__weak ViDocument *document;

	NSHashTable *lists;
}

/** The name of the mark. */
@property(nonatomic,readonly) NSString *name;
/** The line number of the mark. */
@property(nonatomic,readonly) NSUInteger line;
/** The line number of the mark as an NSNumber object. */
@property(nonatomic,readonly) NSNumber *lineNumber;
/** The column number of the mark as an NSNumber object. */
@property(nonatomic,readonly) NSNumber *columnNumber;
/** The column of the mark. */
@property(nonatomic,readonly) NSUInteger column;
/** The character index of the mark, or NSNotFound if unknown. */
@property(nonatomic,readonly) NSUInteger location;
/** The range of the mark, or `{NSNotFound,0}` if unknown. */
@property(nonatomic,readonly) NSRange range;
/** The URL of the mark. */
@property(nonatomic,readonly) NSURL *url;
/** The icon of the mark. */
@property(nonatomic,readwrite,assign) NSImage *icon;
/** The title of the mark. An NSString or an NSAttributedString. */
@property(nonatomic,readwrite,assign) id title;

@property(nonatomic,readonly) __weak ViDocument *document;

@property(nonatomic,readonly) NSString *groupName;

+ (ViMark *)markWithURL:(NSURL *)aURL
		   name:(NSString *)aName
                 title:(id)aTitle
                  line:(NSUInteger)aLine
                column:(NSUInteger)aColumn;

- (ViMark *)initWithURL:(NSURL *)aURL
		   name:(NSString *)aName
		  title:(id)aTitle
                  line:(NSUInteger)aLine
                column:(NSUInteger)aColumn;

+ (ViMark *)markWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		       range:(NSRange)aRange;

- (ViMark *)initWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		       range:(NSRange)aRange;

- (void)setLocation:(NSUInteger)aLocation;
- (void)setRange:(NSRange)aRange;
- (void)setDocument:(__weak ViDocument *)doc;

- (void)remove;
- (void)registerList:(ViMarkList *)list;

@end
