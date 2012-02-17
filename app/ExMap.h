#import "Nu.h"
#import "ViScope.h"
#import "ViCompletionController.h"

/**
 * A definition of an ex command.
 */
@interface ExMapping : NSObject
{
	NSMutableArray		*_names;
	NSString		*_scopeSelector;

	NSString		*_syntax;
	NSUInteger		 _flags;
	id			 _parameter;

	id<ViCompletionProvider> _completion;

	SEL			 _action;
	NuBlock			*_expression;

	NSString		*_usage;
	NSString		*_help;
}

/** The primary name of this command. */
@property(nonatomic, readonly) NSString *name;
/** All names and aliases of this command. */
@property(nonatomic, readonly) NSArray *names;
/** Syntax string describing the format and arguments of the command.
 *
 * The syntax string consists of the following characters:
 *
 * - `!` -- allow ! directly after command name
 * - `r` -- allow range
 * - `%` -- default to whole file if no range
 * - `+` -- allow "+command" argument
 * - `c` -- allow count > 0
 * - `e` -- allow extra argument(s)
 * - `E` -- require extra argument(s)
 * - `1` -- only one extra argument allowed
 * - `x` -- expand wildcards and filename meta chars ('%' and '#') in extra arguments
 * - `R` -- allow register
 * - `l` -- allow an optional line argument
 * - `L` -- require a line argument
 * - `~` -- allow /regexp/replace/flags argument
 * - `/` -- allow /regexp/flags argument
 * - `|` (bar) -- do NOT end command with a trailing bar
 * - `m` -- command modifies document
 */
@property(nonatomic, readonly) NSString *syntax;
@property(nonatomic, readonly) NSString *scopeSelector;
@property(nonatomic, readonly) NuBlock *expression;
@property(nonatomic, readonly) SEL action;
@property(nonatomic, readwrite, retain) id<ViCompletionProvider> completion;

/** Add an alias to an ex comand.
 * @param aName The alias name that this command will respond to.
 */
- (void)addAlias:(NSString *)aName;

/** Remove an alias from an ex comand.
 * @param aName The alias name to remove.
 */
- (void)removeAlias:(NSString *)aName;

- (ExMapping *)initWithNames:(NSArray *)nameArray
		      syntax:(NSString *)aSyntax
                 expression:(NuBlock *)anExpression
                      scope:(NSString *)aScopeSelector;

- (ExMapping *)initWithNames:(NSArray *)nameArray
		      syntax:(NSString *)aSyntax
                     action:(SEL)anAction
                      scope:(NSString *)aScopeSelector;
@end




/**
 * A collection of ex command definitions.
 */
@interface ExMap : NSObject
{
	NSMutableArray	*_mappings;
}

@property (nonatomic,readonly) NSMutableArray *mappings;

/** The default ex map. */
+ (ExMap *)defaultMap;

- (ExMapping *)lookup:(NSString *)aString
	    withScope:(ViScope *)scope;

/** Look up an ex command definition given the name.
 * @param aString the name of the command. May be abbreviated as long as it is not ambiguous.
 * @returns the defined ex command, or nil if not found.
 */
- (ExMapping *)lookup:(NSString *)aString;

- (ExMapping *)define:(id)aName
	       syntax:(NSString *)aSyntax
		   as:(id)implementation
		scope:(NSString *)aScopeSelector;

/** Add an ex command definition.
 *
 * @param aName The name, and optionally, aliases of the command. This is either
 * an NSString or an NSArray instance. If an array is passed, all entries should
 * be instances of NSString. The first string is taken as the primary name and
 * used in error messages.
 *
 * @param aSyntax A syntax string describing the format of arguments.
 * @param implementation Either an NSString instance naming a selector, or a NuBlock
 * instance specifying a Nu function. The Nu function takes on optional parameter;
 * an instance of ExCommand that describes the arguments.
 *
 * @returns the command definition, or nil on error.
 * @see [ExMapping syntax]
 */
- (ExMapping *)define:(id)aName
	       syntax:(NSString *)aSyntax
		   as:(id)implementation;
@end

