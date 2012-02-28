@class ViDocument;
@class ViMarkList;
@class ViDocumentView;
@class ViScope;

/** A marked location.
 */
@interface ViMark : NSObject <NSCopying>
{
	NSString		*_name;
	NSUInteger		 _location;
	NSRange			 _range;
	NSInteger		 _line;
	NSInteger		 _column;
	BOOL			 _persistent;

	NSString		*_rangeString;
	BOOL			 _rangeStringIsDirty;

	BOOL			 _recentlyRestored;

	id			 _title;
	NSArray			*_scopes;
	NSImage			*_icon;
	id			 _representedObject;

	NSString		*_groupName;
	NSURL			*_url;
	ViDocument		*_document;
	__weak ViDocumentView	*_view;

	NSHashTable		*_lists; // XXX: lists are not retained!
}

/** The name of the mark. */
@property(nonatomic,readonly) NSString *name;
/** The line number of the mark. */
@property(nonatomic,readonly) NSInteger line;
/** The column of the mark. */
@property(nonatomic,readonly) NSInteger column;
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
@property(nonatomic,readwrite,copy) id title;
/** A custom user-defined object associated with the mark. */
@property(nonatomic,readwrite,retain) id representedObject;
/** If NO, the mark is automatically removed when the text range is removed. Default is YES. */
@property(nonatomic,readwrite) BOOL persistent;
/** Additional scopes for the marked range. */
@property(nonatomic,readwrite,retain) NSArray *scopes;

@property(nonatomic,readwrite) BOOL recentlyRestored;

@property(nonatomic,readwrite,retain) ViDocument *document;
@property(nonatomic,readonly) __weak ViDocumentView *view;

@property(nonatomic,readonly) NSString *groupName;

+ (ViMark *)markWithURL:(NSURL *)aURL;

+ (ViMark *)markWithURL:(NSURL *)aURL
		   line:(NSInteger)aLine
		 column:(NSInteger)aColumn;

+ (ViMark *)markWithURL:(NSURL *)aURL
		   name:(NSString *)aName
                 title:(id)aTitle
                  line:(NSInteger)aLine
                column:(NSInteger)aColumn;

- (ViMark *)initWithURL:(NSURL *)aURL
		   name:(NSString *)aName
		  title:(id)aTitle
                  line:(NSInteger)aLine
                column:(NSInteger)aColumn;

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
- (void)unregisterList:(ViMarkList *)list;

@end
