#import "ViTransformer.h"

@class ViSnippet;

@interface ViTabstop : NSObject
{
	NSInteger	 _num;
	NSRange		 _range;
	NSUInteger	 _index;
	NSMutableString	*_value;
	ViTabstop	*_parent;
	ViTabstop	*_mirror;
	ViRegexp	*_rx;
	NSString	*_format;
	NSString	*_options;
	NSString	*_filter;
}

@property(readwrite) NSInteger num;
@property(readwrite) NSUInteger index;
@property(readwrite) NSRange range;
@property(readwrite,retain) ViTabstop *parent;
@property(readwrite,retain) ViTabstop *mirror;
@property(readwrite,retain) ViRegexp *rx;
@property(readwrite,retain) NSString *format;
@property(readwrite,retain) NSString *options;
@property(readwrite,retain) NSString *filter;
@property(readwrite,retain) NSMutableString *value;

@end




@protocol ViSnippetDelegate <NSObject>
- (void)snippet:(ViSnippet *)snippet replaceCharactersInRange:(NSRange)range withString:(NSString *)string forTabstop:(ViTabstop *)tabstop;
- (NSString *)string;
@end




@interface ViSnippet : ViTransformer
{
	NSUInteger			 _beginLocation;
	ViTabstop			*_currentTabStop;
	NSUInteger			 _currentTabNum;
	NSUInteger			 _maxTabNum;
	__weak id<ViSnippetDelegate>	 _delegate;	// XXX: not retained!
	NSRange				 _range;
	NSUInteger			 _caret;
	NSRange				 _selectedRange;
	NSMutableArray			*_tabstops;
	NSDictionary			*_environment;
	BOOL				 _finished;
}

@property(nonatomic,readonly) NSRange range;
@property(nonatomic,readonly) NSUInteger caret;
@property(nonatomic,readonly) NSRange selectedRange;
@property(nonatomic,readonly) BOOL finished;
@property(nonatomic,readwrite,retain) ViTabstop *currentTabStop;

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                     delegate:(__weak id<ViSnippetDelegate>)aDelegate
                  environment:(NSDictionary *)environment
                        error:(NSError **)outError;
- (BOOL)activeInRange:(NSRange)aRange;
- (BOOL)replaceRange:(NSRange)updateRange withString:(NSString *)replacementString;
- (BOOL)advance;
- (void)deselect;
- (NSRange)tabRange;
- (NSString *)string;

- (BOOL)updateTabstopsError:(NSError **)outError;
- (void)removeNestedIn:(ViTabstop *)parent;
- (NSUInteger)parentLocation:(ViTabstop *)ts;

@end
