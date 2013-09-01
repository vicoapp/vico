(class ViStatusEventLabel is ViStatusLabel
  (ivar (id) transformer
        (int) handler-id)

  (+ statusLabelForEvent:(id)event withTransformer:(id)transformer is
    ((self alloc) initWithEvent:event transformer:transformer))

  (- initWithEvent:(id)event transformer:(id)transformer is
    (super init)

    (set @handler-id
      (event-manager
        on:event
        do:(do (*args)
          (let ((current-value ((self control) stringValue))
                (new-value (eval (cons transformer *args))))
              (if (and new-value (not (current-value isEqualToString:new-value)))
                  ((self control) setStringValue:new-value)
                  (self invalidateSize))))))

    self)

  (- (void)dealloc is
    (event-manager remove:@handler-id)

    (super dealloc)))

(function vi-status-caret-label ()
  ((ViStatusNotificationLabel alloc)
          initWithNotification:"ViCaretChangedNotification"
              transformerBlock:
                (do (status-view notification)
                  (let (text-view (notification object))
                    (if (!= (text-view window) (status-view window))
                      nil
                      (else
                        "#{(text-view currentLine)}, #{(text-view currentColumn)}"))))))

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

(function filename-for-event (window document)
  (let (url (document fileURL))
      (if url
         (url displayString)
         (else
               "[untitled]"))))

(function vi-status-filename-label ()
  (ViStatusEventLabel statusLabelForEvent:"didSelectDocument" withTransformer:filename-for-event))

(set $vi-status-caret-label vi-status-caret-label)
(set $vi-status-mode-label vi-status-mode-label)
(set $vi-status-filename-label vi-status-filename-label)

# Set up default status bar.
((NSApp delegate) setStatusSetupBlock:
  (do (status-view)
    (let ((caret (vi-status-caret-label))
          (mode (vi-status-mode-label)))
      (status-view
        setStatusComponents:((list caret mode) array)))))
