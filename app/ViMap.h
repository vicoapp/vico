/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "Nu.h"
#import "ViScope.h"

// TODO ViMapNeedArgumentBeforeToggle
// TODO This means we need an argument for the first invocation
// TODO but not the second, and then we need one again.
// TODO This describes the way macro recording works as q<register>
// TODO followed by just q to end recording.
#define ViMapSetsDot			1ULL
#define ViMapNeedMotion			2ULL
#define ViMapIsMotion			4ULL
#define ViMapLineMode			8ULL
#define ViMapUpdatesAllCursors  16ULL
#define ViMapNeedArgument		32ULL
#define ViMapNoArgumentOnToggle	64ULL

/** A mapping of a key sequence to an editor action, macro or Nu expression.
 *
 * New mappings are created in a ViMap.
 *
 * ## Constants
 *
 * ### Map flags
 *
 * - `ViMapSetsDot`: This command sets the dot command
 * - `ViMapNeedMotion`: This command needs a following motion command (ie, it's an operator)
 * - `ViMapIsMotion`: This is a motion command
 * - `ViMapLineMode`: This command operates on whole lines
 * - `ViMapUpdatesAllCursors`: This command updates all cursors when there are more than one
 * - `ViMapNeedArgument`: This command needs a following character argument
 */
@interface ViMapping : NSObject
{
	NSArray		*_keySequence;
	NSString	*_keyString;
	NSString	*_scopeSelector;
	NSString	*_title;

	SEL		 _action;
	NSUInteger	 _flags;
	id		 _parameter;

	BOOL		 _recursive;
	NSString	*_macro;
	NuBlock		*_expression;
}

/** @name Getting mapping attributes */

/** The scope this mapping applies to. */
@property (nonatomic, readonly) NSString *scopeSelector;

/** A string describing the key sequence. */
@property (nonatomic, readonly) NSString *keyString;

/** An array of NSNumbers that make up the key sequence. */
@property (nonatomic, readonly) NSArray *keySequence;

/** Short description of the command. */
@property (nonatomic, readwrite, copy) NSString *title;

/** The editor action. */
@property (nonatomic, readonly) SEL action;

@property (nonatomic, readonly) NSUInteger flags;

/** YES if this macro should be evaluated recursively. */
@property (nonatomic, readonly) BOOL recursive;

/** A key string describing the keys that make up the macro. */
@property (nonatomic, readonly) NSString *macro;

/** A Nu expression macro. */
@property (nonatomic, readonly) NuBlock *expression;

/** Any parameter that should be passed to the command. */
@property (nonatomic, readonly) id parameter;

/** YES if the mapping is an editor action. */
- (BOOL)isAction;

/** YES if the mapping is a macro. */
- (BOOL)isMacro;

/** YES if the mapping is a Nu expression. */
- (BOOL)isExpression;

/** YES if the mapping is an operator action that requires a motion component. */
- (BOOL)isOperator;

/** YES if the mapping is a motion action. */
- (BOOL)isMotion;

/** YES if the mapping is an editor action that works on whole lines. */
- (BOOL)isLineMode;

/** YES if the mapping is an editor action that updates all cursors when there are more than one. */
- (BOOL)updatesAllCursors;

/** YES if the mapping is an editor action that needs a character argument, like the vi `f` command. */
- (BOOL)needsArgument;

/** YES if the mapping is an editor action that does not need a character argument every other invocation, like the vim `q` command. */
- (BOOL)noArgumentOnToggle;

- (BOOL)wantsKeys;

+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
			       action:(SEL)anAction
				flags:(NSUInteger)flags
			    parameter:(id)parameter
				scope:(NSString *)aSelector;
+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
				macro:(NSString *)aMacro
			    recursive:(BOOL)recursiveFlag
				scope:(NSString *)aSelector;
+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
			   expression:(NuBlock *)expr
				scope:(NSString *)aSelector;

- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			    action:(SEL)anAction
			     flags:(NSUInteger)flags
			 parameter:(id)param
			     scope:(NSString *)aSelector;
- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			     macro:(NSString *)aMacro
			 recursive:(BOOL)recursiveFlag
			     scope:(NSString *)aSelector;

- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			expression:(NuBlock *)anExpression
			     scope:(NSString *)aSelector;

@end

/** A map contains keys (or key sequences) mapped to editor actions, macros or Nu expressions.
 *
 * A key sequence is a string of one or more keys. A key can be a
 * regular character like 'a' or '€'. Key characters are case sensitive,
 * so 'a' is different from 'A'.
 *
 * Special keys are specified as a string within angle brackets,
 * like `<f4>`, `<down>` or `<enter>`. Modifiers are prepended with
 * a separating dash, like `<control-f4>`, `<command-down>` or
 * `<alt-enter>`. Multiple modifiers are also possible: `<alt-command-tab>`.
 * The order of modifiers is not significant.
 *
 * The following modifiers are recognized:
 *
 * - `control`, `ctrl` or `c` -- Control modifier
 * - `option`, `alt`, `meta`, `a` or `m` -- Option modifier
 * - `command`, `cmd` or `d` -- Command modifier
 * - `shift` or `s` -- Shift modifier
 *
 * For single character keys, the `shift` modifier should not be
 * used. Use the corresponding upper case character instead. The same
 * applies to the `option` modifier; if the generated character is a
 * valid unicode character, use that character and drop the `option`
 * modifier.
 *
 * The following special keys are recognized:
 *
 * - `delete` or `del` -- Delete function key
 * - `left` -- Left arrow key
 * - `right` -- Right arrow key
 * - `up` -- Up arrow key
 * - `down` -- Down arrow key
 * - `pageup` or `pgup` -- Page Up function key
 * - `pagedown` or `pgdn` -- Page Down function key
 * - `home` -- Home function key
 * - `end` -- End function key
 * - `insert` or `ins` -- Insert function key
 * - `help` -- Help function key
 * - `backspace` or `bs` -- Backspace key
 * - `tab` -- Tab key
 * - `escape` or `esc` -- Escape key
 * - `cr`, `enter` or `return` -- Enter key
 * - `bar` -- `|` key
 * - `lt` -- `<` key
 * - `backslash` or `bslash` -- `\` key
 * - `nl` -- Same as `<control-j>`
 * - `ff` -- Same as `<control-l>`
 * - `nul` -- Null key
 *
 * Mappings that are limited by a scope selector will only be recognized if
 * the current scope matches the selector. If multiple mappings match the
 * current scope, the scope selector with the highest rank is used. Mappings
 * with an empty scope selector has the lowest possible rank.
 */
@interface ViMap : NSObject
{
	NSString	*_name;
	NSMutableArray	*_actions;
	NSMutableSet	*_includes;
	ViMap		*_operatorMap;
	SEL		 _defaultAction;
	NSUInteger _defaultActionFlags;
	SEL		 _defaultCatchallAction;
	BOOL		 _acceptsCounts; /* Default is YES. Disabled for insertMap. */
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray *actions;

/** Assign a map to be used by operator actions. */
@property (nonatomic, readwrite, retain) ViMap *operatorMap;

/** If YES, leading digits acts as count to commands.
 * If NO, digits are treated as normal commands.
 *
 * `acceptsCounts` should be disabled for maps in insert mode.
 * Default is YES.
 */
@property (nonatomic, readwrite) BOOL acceptsCounts;

/** If no mapping matches a key sequence, this action is called. */
@property (nonatomic, readwrite) SEL defaultAction;
/** If no mapping matches a key sequence, this action is called. Similar
    to defaultAction, but defaultAction passes on most characters, while
	defaultCatchallAction passes on all unmatched key sequences, no matter
	what characters are involved. */
@property (nonatomic, readwrite) SEL defaultCatchallAction;

+ (void)clearAll;
+ (NSArray *)allMaps;

/** @name Creating custom maps */

/** Create a new empty map.
 * @param mapName The name of the map.
 * @returns The newly created map. It is initially empty.
 */
+ (ViMap *)mapWithName:(NSString *)mapName;

- (ViMap *)initWithName:(NSString *)aName;

/** @name Predefined standard maps */

/**
 * @returns The map used in insert mode.
 */
+ (ViMap *)insertMap;

/**
 * @returns The map used in normal mode.
 */
+ (ViMap *)normalMap;

/**
 * @returns The map used after an operator command.
 */
+ (ViMap *)operatorMap;

/**
 * @returns The map used in visual mode.
 */
+ (ViMap *)visualMap;

/**
 * @returns The map used in the file explorer sidebar.
 */
+ (ViMap *)explorerMap;

/**
 * @returns The map used in the symbol list sidebar.
 */
+ (ViMap *)symbolMap;

/**
 * @returns The map used in completion popups.
 */
+ (ViMap *)completionMap;

/** @name Including other maps */

/** Check if a map is included by another map.
 * @param aMap The map to check for inclusion.
 * @returns YES if the given map is included by this map.
 */
- (BOOL)includesMap:(ViMap *)aMap;

/** Add a reference to another map.
 *
 * Mappings in an included map can be overridden by mappings in the parent map.
 *
 * @param map The other map to include in this map.
 */
- (void)include:(ViMap *)map;

- (void)setDefaultAction:(SEL)action flags:(NSUInteger)flags;

- (ViMapping *)lookupKeySequence:(NSArray *)keySequence
                       withScope:(ViScope *)scope
                     allowMacros:(BOOL)allowMacros
                      excessKeys:(NSArray **)excessKeys
                         timeout:(BOOL *)timeoutPtr
                           error:(NSError **)outError;

/** @name Mapping macros */

/** Map a key sequence to a macro.
 * @param keySequence The key sequence to map. Can include special keys within angle brackets, like `<cmd-ctrl-up>`.
 * @param macro The key sequence that make up the macro.
 * @param recursiveFlag YES if the macro should be evaluated recursively.
 * @param scopeSelector A scope selector limiting where this key sequence is applicable, or nil for no limit.
 */
- (ViMapping *)map:(NSString *)keySequence
		to:(NSString *)macro
       recursively:(BOOL)recursiveFlag
	     scope:(NSString *)scopeSelector;

/** Map a key sequence to a macro non-recursively.
 * @param keySequence The key sequence to map.
 * @param macro The key sequence that make up the macro.
 * @param scopeSelector A scope selector limiting where this key sequence is applicable, or nil for no limit.
 * @see map:to:recursively:scope:
 */
- (ViMapping *)map:(NSString *)keySequence
		to:(NSString *)macro
	     scope:(NSString *)scopeSelector;

/** Globally map a key sequence to a macro non-recursively.
 * @param keySequence The key sequence to map.
 * @param macro The key sequence that make up the macro.
 * @see map:to:scope:
 */
- (ViMapping *)map:(NSString *)keySequence
         to:(NSString *)macro;

/** @name Mapping Nu expressions */

/** Map a key sequence to a Nu expression.
 * @param keySequence The key sequence to map. Can include special keys within angle brackets, like `<cmd-ctrl-up>`.
 * @param expr A Nu anonymous function (`do` block) with zero arguments. See the [Nu documentation](http://programming.nu/operators#functions).
 * @param scopeSelector A scope selector limiting where this key sequence is applicable, or nil for no limit.
 */
- (ViMapping *)map:(NSString *)keySequence toExpression:(id)expr scope:(NSString *)scopeSelector;

/** Map a key sequence to a Nu expression.
 *
 * The mapping will be created with global scope, ie no limiting scope selector.
 *
 * @param keySequence The key sequence to map.
 * @param expr A Nu anonymous function (`do` block) with zero arguments. See the [Nu documentation](http://programming.nu/operators#functions).
 * @see map:toExpression:scope:
 */
- (ViMapping *)map:(NSString *)keySequence toExpression:(id)expr;

/** @name Mapping keys to actions */

/** Map a key sequence to an action.
 * @param keyDescription The key sequence to map. Can include special keys within angle brackets, like `<cmd-ctrl-up>`.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together.
 * @param param Any parameter that should be passed to the command.
 * @param scopeSelector A scope selector limiting where this key sequence is applicable, or nil for no limit.
 */
- (ViMapping *)setKey:(NSString *)keyDescription
      toAction:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;

/** Map a key sequence to an action.
 *
 * This sets flags to 0, parameter to nil and empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @see setKey:toAction:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
      toAction:(SEL)selector;

/** Map a key sequence to an action with the given flags.
 *
 * This sets parameter to nil and empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together.
 * @see setKey:toAction:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
      toAction:(SEL)selector
		flags:(NSUInteger)flags;

/** Map a key sequence to a motion action.
 * @param keyDescription The key sequence to map. Can include special keys within angle brackets, like `<cmd-ctrl-up>`.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together. The `ViMapIsMotion` flag is always set.
 * @param param Any parameter that should be passed to the command.
 * @param scopeSelector A scope selector limiting where this key sequence is applicable, or nil for no limit.
 * @see setKey:toAction:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
      toMotion:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;

/** Map a key sequence to a motion action.
 *
 * This sets flags to `ViMapIsMotion`, parameter to `nil` and an empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @see setKey:toMotion:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
      toMotion:(SEL)selector;


/** Map a key sequence to a motion action with the given flags.
 *
 * This sets parameter to `nil` and an empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together. The `ViMapSetsDot` flag is always set.
 * @see setKey:toMotion:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
      toMotion:(SEL)selector
		flags:(NSUInteger)flags;

/** Map a key sequence to an edit action.
 * @param keyDescription The key sequence to map. Can include special keys within angle brackets, like `<cmd-ctrl-up>`.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together. The `ViMapSetsDot` flag is always set.
 * @param param Any parameter that should be passed to the command.
 * @param scopeSelector A scope selector limiting where this key sequence is applicable, or nil for no limit.
 * @see setKey:toAction:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
  toEditAction:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;


/** Map a key sequence to an edit action.
 *
 * This sets flags to `ViMapSetsDot`, parameter to `nil` and an empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @see setKey:toEditAction:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
  toEditAction:(SEL)selector;

/** Map a key sequence to an edit action with the given flags.
 *
 * This sets parameter to `nil` and an empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together. The `ViMapSetsDot` flag is always set.
 * @see setKey:toEditAction:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
  toEditAction:(SEL)selector;

/** Map a key sequence to an operator action.
 * @param keyDescription The key sequence to map. Can include special keys within angle brackets, like `<cmd-ctrl-up>`.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together. The `ViMapNeedMotion` flag is always set.
 * @param param Any parameter that should be passed to the command.
 * @param scopeSelector A scope selector limiting where this key sequence is applicable, or nil for no limit.
 * @see setKey:toAction:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
    toOperator:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;

/** Map a key sequence to an operator action.
 *
 * This sets flags to `ViMapNeedMotion`, parameter to `nil` and an empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @see setKey:toOperator:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
    toOperator:(SEL)selector;

/** Map a key sequence to an operator action with the given flags.
 *
 * This sets parameter to `nil` and an empty scope selector.
 *
 * @param keyDescription The key sequence to map.
 * @param selector The selector of the action.
 * @param flags A combination of flags, or'd together. The `ViMapNeedMotion` flag is always set.
 * @see setKey:toOperator:flags:parameter:scope:
 */
- (ViMapping *)setKey:(NSString *)keyDescription
    toOperator:(SEL)selector
	  flags:(NSUInteger)flags;

/** @name Unmapping keys */

/** Unmap a key sequence in a specific scope.
 * @param keySequence The key sequence to unmap.
 * @param scopeSelector A scope selector matching a previously mapped key sequence.
 */
- (void)unmap:(NSString *)keySequence
        scope:(NSString *)scopeSelector;

/** Unmap a key sequence without a limiting scope.
 * @param keySequence The key sequence to unmap.
 * @see unmap:scope:
 */
- (void)unmap:(NSString *)keySequence;

- (void)exclude:(ViMap *)map;
- (void)remove;

@end
