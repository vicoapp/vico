(function vi-status-caret-label ()
  ((ViStatusNotificationLabel alloc)
           initWithNotification:"ViCaretChangedNotification"
               transformerBlock:
                 (do (notification)
                    (let (text-view (notification object))
                      "#{(text-view currentLine)}, #{(text-view currentColumn)}"))))

(function mode-for-notification (status-view notification)
  (let (text-view (notification object))
    (cond
      ((eq (text-view superview) nil) nil)
      ((!= (text-view window) (status-view window)) nil)
      (else
        (let ((document (text-view document))
              (current-mode (text-view mode)))
          (let (mode
                 (cond
                   ((document busy) "--BUSY--")
                   ((eq current-mode ViInsertMode)
                     (if (document snippet)
                       "--SNIPPET--"
                       (else
                         "--INSERT--")))
                    ((eq current-mode ViVisualMode)
                      (if (text-view visual_line_mode)
                        "--VISUAL LINE--"
                        (else
                          "--VISUAL--")))
                    (else "")))
            "    #{mode}"))))))

(function vi-status-mode-label ()
  ((ViStatusNotificationLabel alloc)
           initWithNotification:"ViModeChangedNotification"
               transformerBlock:(do (status-view notification) (mode-for-notification status-view notification))))

# Set up default status bar.
((NSApp delegate) setStatusSetupBlock:
  (do (status-view)
    (let ((caret (vi-status-caret-label))
          (mode (vi-status-mode-label)))
      (status-view
        setStatusComponents:((list caret mode) array)))))
