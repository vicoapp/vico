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
            
            for var helper in helperConfig.helpers {
                helper.textView = textView
            }
        }
    }
    
    private var _helperConfig: ViRulerHelperConfig = ViRulerHelperConfig()
    private var helperConfig: ViRulerHelperConfig {
        get {
            if let textView = self.textView where _helperConfig.helpers.isEmpty {
                _helperConfig = ViRulerHelperConfig.defaultHelpersForTextView(textView, backgroundColor: backgroundColor)
                
                _helperConfig.installOnRuler(self)
            }
            
            return _helperConfig
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
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.reservedThicknessForAccessoryView = 0
        self.reservedThicknessForMarkers = 0
    }

    required init?(coder: NSCoder) {
        fatalError("ViRulerView currently doesn't support coding/decoding.")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func layout() {
        super.layout()
        
        let newThickness = fittingSize.width
        if newThickness != ruleThickness {
            // Delay this update, as running it directly in response to the notifications
            // that trigger it can result in exceptions all over the layout manager.
            NSOperationQueue.mainQueue().addOperationWithBlock({ [weak self] () -> Void in
                self?.ruleThickness = newThickness
            })
        }
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
        fillBackground()
        drawMargin()
        
        for helperView in helperConfig.helperViews {
            helperView.needsDisplay = true
        }
    }
    
    func resetTextAttributes() {
        NSLog("Shouldn't be resetting text attributes on the ruler view.")
    }
}