@class ViDocument;
@class ViMarkList;
@class ViDocumentView;

/** A marked location.
 */
@interface ViMark : NSObject
{
	NSString		*_name;
	NSUInteger		 _location;
	NSRange			 _range;
	NSUInteger		 _line;
	NSUInteger		 _column;

	NSString		*_rangeString;
	BOOL			 _rangeStringIsDirty;

	id			 _title;
	NSImage			*_icon;

	NSString		*_groupName;
	NSURL			*_url;
	ViDocument		*_document;
	__weak ViDocumentView	*_view;

	NSHashTable		*_lists; // XXX: lists are not retained!
}

/** The name of the mark. */
@property(nonatomic,readonly) NSString *name;
/** The line number of the mark. */
@property(nonatomic,readonly) NSUInteger line;
/** The column of the mark. */
@property(nonatomic,readonly) NSUInteger column;
/** The character index of the mark, or NSNotFound if unknown. */
@property(nonatomic,readonly) NSUInteger location;
/** The range of the mark, or `{NSNotFound,0}` if unknown. */
@property(nonatomic,readonly) NSRange range;
/** The range of the mark as a string, or `nil` if unknown. */
@property(nonatomic,readonly) NSString *rangeString;
/** The URL of the mark. */
@property(nonatomic,readonly) NSURL *url;
/** The icon of the mark. */
@property(nonatomic,readwrite,retain) NSImage *icon;
/** The title of the mark. An NSString or an NSAttributedString. */
@property(nonatomic,readwrite,retain) id title;

@property(nonatomic,readwrite,retain) ViDocument *document;
@property(nonatomic,readonly) __weak ViDocumentView *view;

@property(nonatomic,readonly) NSString *groupName;

+ (ViMark *)markWithURL:(NSURL *)aURL;

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

+ (ViMark *)markWithView:(ViDocumentView *)aDocumentView
		    name:(NSString *)aName
		   range:(NSRange)aRange;

- (ViMark *)initWithView:(ViDocumentView *)aDocumentView
		    name:(NSString *)aName
		   range:(NSRange)aRange;

- (void)setLocation:(NSUInteger)aLocation;
- (void)setRange:(NSRange)aRange;
- (void)setURL:(NSURL *)url;

- (void)remove;
- (void)registerList:(ViMarkList *)list;

@end
