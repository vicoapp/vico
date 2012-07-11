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

#import "ViMap.h"
#import "ViCommand.h"
#import "ViScope.h"

typedef enum {
	ViParserInitialState,		/* expecting a command, or " */
	ViParserNeedRegister,		/* after a " */
	ViParserPartialCommand,		/* got a prefix, eg g or <c-w> */
	ViParserNeedMotion,		/* for operators */
	ViParserPartialMotion,		/* for operators, prefix motions, eg g */
	ViParserNeedChar		/* for ftFTr */
} ViParserState;

/** A parser for vi commands.
 *
 */
@interface ViParser : NSObject
{
	ViMap		*_defaultMap;
	ViMap		*_map;

	ViParserState	 _state;

	NSMutableArray	*_keySequence;
	NSMutableArray	*_totalKeySequence;

	NSArray		**_remainingExcessKeysPtr; // XXX: not retained

	ViCommand	*_command;
	unichar		 _reg; /* register */
	int		 _count;

	/* dot state */
	ViCommand	*_dotCommand;

	/* Used for nvi-style undo. */
	BOOL		 _nviStyleUndo;
	ViCommand	*_lastCommand;
	ViCommand	*_lastToggleCommand;

	ViCommand	*_lastLineSearchCommand;

	// search state (XXX: move to "/ register?)
	int		 _lastSearchOptions;
}

/** Change the current key map.
 * @param aMap A new key map that should be used to parse following keys.
 */
@property(nonatomic,readwrite,retain) ViMap *map;

@property(nonatomic,readwrite) BOOL nviStyleUndo;
@property(nonatomic,readwrite) int lastSearchOptions;

@property(nonatomic,readwrite,retain) ViCommand *command;
@property(nonatomic,readwrite,retain) ViCommand *dotCommand;
@property(nonatomic,readwrite,retain) ViCommand *lastCommand;
@property(nonatomic,readwrite,retain) ViCommand *lastToggleCommand;
@property(nonatomic,readwrite,retain) ViCommand *lastLineSearchCommand;

+ (ViParser *)parserWithDefaultMap:(ViMap *)aMap;

/** Initialize a new key parser.
 * @param aMap The default map to use when mapping keys.
 * @see ViMap
 */
- (ViParser *)initWithDefaultMap:(ViMap *)aMap;

- (id)pushKey:(NSInteger)keyCode;

- (id)pushKey:(NSInteger)keyCode
  allowMacros:(BOOL)allowMacros
        scope:(ViScope *)scope
      timeout:(BOOL *)timeoutPtr
   excessKeys:(NSArray **)excessKeysPtr
        error:(NSError **)outError;

- (id)timeoutInScope:(ViScope *)scope
               error:(NSError **)outError;

/** Reset the parser.
 *
 * Parser state is reset and any partial keys are discarded.  The key
 * map is reset to the default map defined when the parser was created.
 */
- (void)reset;

- (void)setVisualMap;
- (void)setInsertMap;
- (void)setExplorerMap;

/**
 * @returns YES if there are partial keys received.
 */
- (BOOL)partial;

/**
 * @returns The current keys being parsed, or the empty string if not
 * partial keys received.
 */
- (NSString *)keyString;

@end
