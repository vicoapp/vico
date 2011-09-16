; Experimental implementation of texmate's dialog infrastructure.
; Completion support.
;
; Copyright (c) 2011 Martin Hedenfalk <martin@bzero.se>
;
; Permission to use, copy, modify, and distribute this software for any
; purpose with or without fee is hereby granted, provided that the above
; copyright notice and this permission notice appear in all copies.
;
; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
; OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

(class TmCompletionProvider is NSObject
	(unless ($TmProviderLoaded)
		(set $TmProviderLoaded t)
		(ivar (id)completions))

	(- (id) initWithArray:(id) anArray is
		(super init)
		(set @completions anArray)
		(self))

	(- (void) completionsForString:(id) aString options:(id) options target:(id)target action:(SEL)action is
		(target performSelector:action withObject:@completions withObject:nil) ))

(unless (defined choices)
	(shellCommand log:"missing choices")
	(shellCommand exitWithError:1)
(else
	(set text (current-text))
	(set window (current-window))
	; (shellCommand log:"choices are: #{(choices description)}")
	(set range `(,(- (text caret) (initial_filter length)) ,(initial_filter length)))
	(unless (initial_filter)
		(set wordRange ((text textStorage) rangeOfWordAtLocation:(text caret) acceptAfter:YES extraCharacters:extra_chars))
		(unless (eq (first wordRange) -1)
			(set range wordRange)
			(set initial_filter (((text textStorage) string) substringWithRange:range)) ))
	; (shellCommand log:"initial filter is #{initial_filter} in range #{range}")
	(NSApp activateIgnoringOtherApps:YES)
	(set cc (ViCompletionController sharedController))
	(set completions (choices map: (do (choice)
		(set content (or (choice objectForKey:"match") (choice objectForKey:"display")))
		(set c (ViCompletion completionWithContent:content))
		(c setRepresentedObject:choice)
		c)))
	(set point ((text layoutManager) boundingRectForGlyphRange:`(,(text caret) 0)
						   inTextContainer:(text textContainer)))
	(set screenPoint ((window window) convertBaseToScreen:(text convertPointToBase:point)))
	(set provider ((TmCompletionProvider alloc) initWithArray:completions))
	(set choice (cc chooseFrom:provider range:range prefix:initial_filter at:screenPoint options:"f" direction:0 initialFilter:""))
	; (shellCommand log:"got choice: #{(choice description)}")
	; (shellCommand log:"termination character was: #{(NSString stringWithKeyCode:(cc terminatingKey))}")
	(if (choice)
		(text replaceRange:(cc range) withString:(choice content))
		(text setCaret:(+ (first (cc range)) ((choice content) length)))
		(set result (NSMutableDictionary dictionary))
		(result setObject:(choice representedObject) forKey:"representedObject")
		(result setObject:(completions indexOfObject:choice) forKey:"index")
		;(result setObject:(choice content) forKey:"insert")
		; (shellCommand log:"exiting with object #{(result description)}")
		(shellCommand exitWithObject:result)
	(else
		(shellCommand exitWithError:1) ))))

