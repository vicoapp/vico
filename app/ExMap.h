#import <Nu/Nu.h>
#import "ViScope.h"
#import "ViCompletionController.h"

@interface ExMapping : NSObject
{
	NSArray *names;
	NSString *scopeSelector;

	NSString *syntax;
	NSUInteger flags;
	id parameter;

	id<ViCompletionProvider> completion;

	SEL action;
	NuBlock *expression;

	NSString *usage;
	NSString *help;
}

@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSArray *names;
@property(nonatomic, readonly) NSString *syntax;
@property(nonatomic, readonly) NSString *scopeSelector;
@property(nonatomic, readonly) NuBlock *expression;
@property(nonatomic, readonly) SEL action;
@property(nonatomic, assign, readwrite) id<ViCompletionProvider> completion;

- (ExMapping *)initWithNames:(NSArray *)nameArray
		      syntax:(NSString *)aSyntax
                 expression:(NuBlock *)anExpression
                      scope:(NSString *)aScopeSelector;

- (ExMapping *)initWithNames:(NSArray *)nameArray
		      syntax:(NSString *)aSyntax
                     action:(SEL)anAction
                      scope:(NSString *)aScopeSelector;
@end

@interface ExMap : NSObject
{
	NSMutableArray *mappings;
}

@property (nonatomic,readonly) NSMutableArray *mappings;

+ (ExMap *)defaultMap;

- (ExMapping *)lookup:(NSString *)aString
	    withScope:(ViScope *)scope;

- (ExMapping *)lookup:(NSString *)aString;

/*
 *
 *  ! -- allow ! directly after command name
 *  r -- allow range
 *  % -- default to whole file if no range
 *  + -- allow "+command" argument
 *  c -- allow count > 0
 *  e -- allow extra argument(s)
 *  E -- require extra argument(s)
 *  1 -- only one extra argument allowed
 *  x -- expand wildcards and filename meta chars ('%' and '#') in extra arguments
 *  R -- allow register
 *  l -- allow an optional line argument
 *  L -- require a line argument
 *  ~ -- allow /regexp/replace/flags argument (! may be used as delimiter, unless ! option given?)
 *  / -- allow /regexp/flags argument (! may be used as delimiter, unless ! option given?)
 *  | (bar) -- do NOT end command with a trailing bar
 *  m -- command modifies document
 */

- (ExMapping *)define:(id)aName
	       syntax:(NSString *)aSyntax
		   as:(id)implementation
		scope:(NSString *)aScopeSelector;

- (ExMapping *)define:(id)aName
	       syntax:(NSString *)aSyntax
		   as:(id)implementation;
@end

