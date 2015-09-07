//
//  ViRulerView.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

class ViRulerView: NSRulerView {
    static let rerenderingDocumentNotifications = [ViFoldsChangedNotification, ViFoldOpenedNotification, ViFoldClosedNotification]
    
    private let backgroundColor =
        NSColor(
            deviceRed: (0xED / 0xFF) as CGFloat,
            green: (0xED / 0xFF) as CGFloat,
            blue: (0xED / 0xFF) as CGFloat,
            alpha: 1.0
        )
    private let marginColor =
        NSColor(calibratedWhite: 0.58, alpha: 1.0)
    
    private var textView: ViTextView? {
        willSet {
            if let textView = self.textView {
                NSNotificationCenter.defaultCenter().removeObserver(self,
                    name: ViTextStorageChangedLinesNotification,
                    object: textView.textStorage)
                
                NSNotificationCenter.defaultCenter().removeObserver(self,
                    name: ViCaretChangedNotification,
                    object: textView)
                
                if newValue?.document != textView.document {
                    for notification in ViRulerView.rerenderingDocumentNotifications {
                        NSNotificationCenter.defaultCenter().removeObserver(self,
                            name: notification,
                            object: textView.document)
                    }
                }
            }
        }
        didSet {
            guard let textView = self.textView else {
                fatalError("Tried to use ViRulerView without a text view.")
            }
            
            for var helper in helpers {
                helper.textView = textView
            }
            
            NSNotificationCenter.defaultCenter().addObserver(self,
                selector: "textStorageDidChangeLines:",
                name: ViTextStorageChangedLinesNotification,
                object: textView.textStorage)
            
            NSNotificationCenter.defaultCenter().addObserver(self,
                selector: "ruleThicknessUpdateNeeded:",
                name: ViCaretChangedNotification,
                object: textView)
            
            if oldValue?.document != textView.document {
                for notification in ViLineNumberView.rerenderingDocumentNotifications {
                    NSNotificationCenter.defaultCenter().addObserver(self,
                        selector: "ruleThicknessUpdateNeeded:",
                        name: notification,
                        object: textView.document)
                }
            }
        }
    }
    
    private var _helpers: [ViRulerHelper] = []
    private var helpers: [ViRulerHelper] {
        get {
            if let textView = self.textView where _helpers.isEmpty {
                _helpers = helpersForTextView(textView, backgroundColor: backgroundColor)
                
                for helper in _helpers {
                    let view = helper.helperView
                    
                    self.addSubview(view)
                    NSNotificationCenter.defaultCenter().addObserver(self,
                        selector: "ruleThicknessUpdateNeeded:",
                        name: NSViewFrameDidChangeNotification,
                        object: view
                    )
                }
            }
            
            return _helpers
        }
    }
    
    override var clientView: NSView? {
        didSet {
            textView = clientView as? ViTextView
        }
    }
    override var scrollView: NSScrollView? {
        didSet {
            if let scrollView = self.scrollView, documentView = scrollView.documentView as? NSView {
                clientView = documentView
            }
        }
    }
    
    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .VerticalRuler)
    }

    required init?(coder: NSCoder) {
        fatalError("ViRulerView currently doesn't support coding/decoding.")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func ruleThicknessUpdateNeeded(notification: NSNotification) {
        updateRuleThickness()
    }
    
    @objc func textStorageDidChangeLines(notification: NSNotification) {
        needsDisplay = true
    }
    
    private func updateRuleThickness() {
        let newThickness = helpers.reduce(0, combine: { $0 + $1.helperView.frame.width })
        
        if newThickness != ruleThickness {
            NSOperationQueue.mainQueue().addOperationWithBlock({ [weak self] () -> Void in
                self?.ruleThickness = newThickness
            })
        }
        
        needsDisplay = true
    }
    
    private func fillBackground() {
        backgroundColor.set()
        NSRectFill(bounds)
    }
    
    private func drawMargin() {
        marginColor.set()
        
        let marginThickness: CGFloat = 0.5
        NSBezierPath.strokeLineFromPoint(
            NSMakePoint(NSMaxX(bounds) - marginThickness, NSMinY(bounds)),
            toPoint: NSMakePoint(NSMaxX(bounds) - marginThickness, NSMaxY(bounds))
        )
    }
    
    override func drawHashMarksAndLabelsInRect(rect: NSRect) {
        if let visibleRect = scrollView?.contentView.bounds {
            fillBackground()
            drawMargin()
            
            for helper in helpers {
                helper.drawInRect(rect, visibleRect: visibleRect)
            }
        }
    }
    
    func resetTextAttributes() {
        for helper in helpers {
            helper.resetTextAttributes()
        }
    }
}