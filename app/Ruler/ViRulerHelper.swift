//
//  ViRulerHelper.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

/**
 * A helper for ViRuler that can receive the text view the ruler is
 * rendering for and draw in part of the rectangle. The view aspect
 * of the helper can be looked up by calling `helperView`.
 *
 * See `ViRulerHelperView` for a starting point.
 */
protocol ViRulerHelper {
    
    var textView: ViTextView { get set }
    
    func drawInRect(rect: NSRect, visibleRect: NSRect) -> Void
    
    // All ViRulerHelperViews should be representable by an NSView. Defaulted
    // for those that are already NSViews.
    var helperView: NSView { get }
}

extension ViRulerHelper where Self: NSView {
    var helperView: NSView {
        return self
    }
}

extension ViFoldMarginView: ViRulerHelper {}
extension ViLineNumberView: ViRulerHelper {}
