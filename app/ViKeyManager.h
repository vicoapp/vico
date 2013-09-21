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

#import "ViCommon.h"
#import "ViParser.h"
#import "ViScope.h"

@class ViKeyManager;

/** Protocol defining methods for the target of a key manager.
 */
@protocol ViKeyManagerTarget <NSObject>
@optional

- (ViScope *)currentScopeForKeyManager:(ViKeyManager *)aKeyManager;

/** Intercept keys before parsing.
 * @param aKeyManager The key manager handling the event.
 * @param keyCode The key code that is being parsed.
 * @param scope The active scope.
 * @returns A NSNumber with a boolean YES if the key should be parsed, otherwise NO.
 */
- (NSNumber *)keyManager:(ViKeyManager *)aKeyManager
	  shouldParseKey:(NSNumber *)keyCode
		 inScope:(ViScope *)scope;

/** Present errors from key parsing.
 * @param aKeyManager The key manager handling the event.
 * @param error An error from the vi key parser or map.
 */
- (void)keyManager:(ViKeyManager *)aKeyManager
      presentError:(NSError *)error;

/** Evaluate a generated command.
 *
 * Only normal editor actions are passed to this method. Macros and Nu
 * expressions are evaluated automatically by the key manager.
 *
 * @param keyManager The key manager that handled the event.
 * @param command The generated ViCommand.
 * @returns YES if the command succeded, otherwise NO.
 */
- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command;

/** Notify about partial keys.
 *
 * This method can be used to present partial vi commands.
 * @param keyManager The key manager handling the event.
 * @param keyString A string of partial keys.
 */
- (BOOL)keyManager:(ViKeyManager *)keyManager
  partialKeyString:(NSString *)keyString;
@end

/** The key manager handles key input and macro evaluation.
 *
 * The key manager uses a ViParser to parse key events into a ViCommand.
 */
@interface ViKeyManager : NSObject
{
	NSTimer				*_keyTimeout;
	NSInteger			 _recursionLevel;

    BOOL                 _isRecordingMacro;
    NSMutableString     *_recordedKeys;
    unichar              _pendingMacroRegister;
}

/** The vi key parser used by the key manager.
 * @see ViParser.
 */
@property(nonatomic,readwrite) ViParser *parser;

/** The target object that evaluates the parsed commands. Should conform
 * to the ViKeyManagerTarget protocol.
 */
@property(nonatomic,readwrite) id<ViKeyManagerTarget> target;

@property(nonatomic,readwrite) BOOL isRecordingMacro;

/** @name Initializing */

+ (ViKeyManager *)keyManagerWithTarget:(id<ViKeyManagerTarget>)aTarget
				parser:(ViParser *)aParser;

/** Initialize a new key manager with a target object and a key parser.
 *
 * This is the designated initialzer.
 *
 * @param aTarget The target of generated commands.
 * @param aParser An existing key parser.
 */
- (ViKeyManager *)initWithTarget:(id<ViKeyManagerTarget>)aTarget
                          parser:(ViParser *)aParser;

+ (ViKeyManager *)keyManagerWithTarget:(id<ViKeyManagerTarget>)aTarget
			    defaultMap:(ViMap *)map;

/** Initialize a new key manager with a target object and a default key map.
 * @param aTarget The target of generated commands.
 * @param map The default map to use when creating a new key parser.
 */
- (ViKeyManager *)initWithTarget:(id<ViKeyManagerTarget>)aTarget
                      defaultMap:(ViMap *)map;

/** @name Handling key events */

/** Handle a key equivalent event.
 * @param theEvent A key equivalent event.
 * @returns YES if the key equivalent was handled. NO if the key equivalent was not recognized.
 */
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent;

/** Handle a key equivalent event.
 * @param theEvent A key equivalent event.
 * @param scope The scope where the key equivalent event occurred.
 * @returns YES if the key equivalent was handled. NO if the key equivalent was not recognized.
 */
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent inScope:(ViScope *)scope;

/** Handle a keyDown event.
 * @param theEvent A key event.
 */
- (void)keyDown:(NSEvent *)theEvent;

/** Handle a keyDown event.
 * @param theEvent A key event.
 * @param scope The scope where the key event occurred.
 */
- (void)keyDown:(NSEvent *)theEvent inScope:(ViScope *)scope;

/** Manually parse a key.
 * @param keyCode The key code of the key.
 */
- (BOOL)handleKey:(NSInteger)keyCode;

/** Manually parse a key.
 * @param keyCode The key code of the key.
 * @param scope The scope to consider when parsing the key.
 */
- (BOOL)handleKey:(NSInteger)keyCode inScope:(ViScope *)scope;

- (void)handleKeys:(NSArray *)keys;
- (void)handleKeys:(NSArray *)keys inScope:(ViScope *)scope;

- (ViScope *)currentScope;

- (BOOL)runAsMacro:(NSString *)inputString interactively:(BOOL)interactiveFlag;
- (BOOL)runAsMacro:(NSString *)inputString;

/** Start recording a macro to be saved in the given register. */
- (void)startRecordingMacro:(unichar)reg;
/** Adds the given key string to the currently recording macro. */
- (void)recordKeyForMacro:(NSInteger)key;
/** Stop recording the macro and save its contents to the appropriate register.
 */
- (void)stopRecordingMacroAndSave;
@end

