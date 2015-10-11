//
//  ViRulerHelperView.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 9/6/15.
//
//

import Foundation

/**
 * Convenience base class that handles much of the plumbing needed for
 * a ruler helper view.
 *
 * When you extend this class, you have access to a `textView` property
 * that is already converted to `ViTextView`. Additionally, your view
 * will automatically be redisplayed on all notifications in
 * `ViRulerView.rerenderingDocumentNotifications`. Lastly, your view
 * will have its `textStorageDidChangeLines:` selector invoked when
 * the underlying text view's text storage changes its line contents.
 *
 * You can customize the document notifications that will trigger a
 * redisplay of your view by replacing `redisplayingDocumentNotifications`.
 */
internal class ViRulerHelperView: NSView {
    /**
     * The list of notifications from the ViDocument underlying the text
     * view this ruler view is attached to that will trigger a redisplay
     * of this text view.
     */
    internal let redisplayingDocumentNotifications = ViRulerView.rerenderingDocumentNotifications
    
    internal var _textView: ViTextView? = nil
    internal var textView: ViTextView {
        set(newValue) {
            let oldValue = _textView
            _textView = newValue
            
            let notificationCenter = NSNotificationCenter.defaultCenter()
            
            if oldValue?.document !== newValue.document {
                if let oldDocument = oldValue?.document {
                    for notification in redisplayingDocumentNotifications {
                        notificationCenter.removeObserver(self, name: notification, object: oldDocument)
                    }
                }
                
                let needsDisplayHandler: (NSNotification!)->Void = { [weak self] (_) in
                    self?.needsDisplay = true
                }
                
                for notification in redisplayingDocumentNotifications {
                    notificationCenter.addObserverForName(notification, object: newValue.document, queue: nil, usingBlock: needsDisplayHandler)
                }
            }
            
            if oldValue?.textStorage !== newValue.textStorage {
                if let oldTextStorage = oldValue?.textStorage {
                    notificationCenter.removeObserver(self, name: ViTextStorageChangedLinesNotification, object: oldTextStorage)
                }
                
                notificationCenter.addObserver(self, selector: "textStorageDidChangeLines:", name: ViTextStorageChangedLinesNotification, object: newValue.textStorage)
            }
        }
        get {
            return _textView!
        }
    }
    
    /**
     * Override this method to react to changes in the number of lines
     * in the text storage underlying the text view this ruler view is
     * attached to.
     *
     * Noop by default.
     */
    @objc func textStorageDidChangeLines(notification: NSNotification) {}
}
