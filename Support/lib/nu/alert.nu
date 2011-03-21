; Alert dialog callable from the shell.
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

((NSApplication sharedApplication) activateIgnoringOtherApps:YES)

(unless (defined? buttonTitles)
	(set buttonTitles (NSArray arrayWithList:'("OK" "Cancel"))))
(unless (defined? messageTitle)
	(set messageTitle "Something happened"))
(unless (defined? informativeText)
	(set informativeText "It was unexpected"))
(unless (defined? alertStyle)
	(set alertStyle "informational"))

(set alert ((NSAlert alloc) init))
(buttonTitles each: (do (title)
	(alert addButtonWithTitle:title)))
(alert setMessageText:messageTitle)
(alert setInformativeText:informativeText)
(case alertStyle
	("warning" (alert setAlertStyle:NSWarningAlertStyle))
	("critical" (alert setAlertStyle:NSCriticalAlertStyle))
	(else (alert setAlertStyle:NSInformationalAlertStyle)))

(shellCommand exitWithObject:(- (alert runModal) 1000))

