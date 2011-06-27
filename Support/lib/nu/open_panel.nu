; An open panel callable from vicotool.
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

(NSApp activateIgnoringOtherApps:YES)

(set openPanel (NSOpenPanel openPanel))
(unless (defined options)
	(set options (NSDictionary dictionary)))
(if (set title (options objectForKey:"title"))
	(openPanel setTitle:title))
(openPanel setCanChooseDirectories:YES)
(if (options objectForKey:"select-multiple")
	(openPanel setAllowsMultipleSelection:YES)
        (else (openPanel setAllowsMultipleSelection:NO)))
(if (set path (options objectForKey:"with-directory"))
	(openPanel setDirectoryURL:(NSURL URLWithFilePath:path)))
(openPanel setAllowedFileTypes:nil)

(if NO ;(window window)
	(then
		; This currently crashes
		(openPanel beginSheetModalForWindow:((current-window) window) completionHandler:(cblock void ((int) returnValue)
			;(shellCommand log:"modal panel returned value #{returnValue}")
			(if (eq returnValue 1)
				(shellCommand exitWithObject:(openPanel URLs))
				(else
					(shellCommand exitWithError:1)) ))))
	(else
		(set returnValue (openPanel runModal))
		;(shellCommand log:"return value is #{returnValue}")
		(if (eq returnValue 1)
			(shellCommand exitWithObject:(openPanel URLs))
			(else (shellCommand exitWithError:1)) ) ))

