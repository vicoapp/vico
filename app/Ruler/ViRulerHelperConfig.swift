//
//  ViRulerHelperConfig.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 9/6/15.
//
//

import Foundation

/**
* A struct for representing a configuration of `ViRulerHelper`s.
* Given a set of visual constraints described as a visual constraint
* string and a dictionary of helper name to `ViRulerHelper`, provides
* access to the helpers themselves, the helper views associated, with
* them, and the layout constraints that will bind them together.
*
* The easiest way to apply the config is to call `installOnRuler:` and
* pass it the ruler to install the helpers on. You can also call
* `uninstallFromRuler:` to remove the config and its associated views,
* helpers, and constraints from a ruler.
*/
struct ViRulerHelperConfig {
    /**
     * Returns a default helper config for the given view and background
     * color. Includes a line number view and fold margin view.
     */
    internal static func defaultHelpersForTextView(textView: ViTextView, backgroundColor: NSColor) -> ViRulerHelperConfig {
        return ViRulerHelperConfig(
            visualConstraints: "|[lineNumberView]-(5)-[foldMarginView]|",
            helperDictionary: [
                "lineNumberView": ViLineNumberView(textView: textView, backgroundColor: backgroundColor),
                "foldMarginView": ViFoldMarginView(textView: textView)
            ]
        )
    }
    
    private let visualConstraints: String
    private let helperDictionary: [String: ViRulerHelper]
    
    /**
     * The layout constraints for this helper config.
     *
     * Note that the layout constraints are computed on lookup, and if the
     * underlying configuration references the superview of the helper views,
     * they should not be looked up until the helper views have been added to
     * the superview that will be dealing with the constraints.
     */
    var layoutConstraints: [NSLayoutConstraint] {
        get {
            return NSLayoutConstraint.constraintsWithVisualFormat(visualConstraints, options: NSLayoutFormatOptions.AlignAllTop, metrics: nil, views: helperDictionary.map({ (name, helper) in
                (name, helper.helperView)
            })
            )
        }
    }
    
    /**
     * The helpers in this config.
     */
    var helpers: [ViRulerHelper] {
        get {
            return Array(helperDictionary.values)
        }
    }
    
    /**
     * The helper views for the helpers in this config.
     */
    var helperViews: [NSView] {
        get {
            return helpers.map { $0.helperView }
        }
    }
    
    /**
     * Creates a new helper config with the given visual constraints string and
     * a dictionary of helper names (used in the constraint string as well) to
     * ruler helpers.
     */
    init(visualConstraints: String, helperDictionary: [String: ViRulerHelper]) {
        self.visualConstraints = visualConstraints
        self.helperDictionary = helperDictionary
    }
    
    /**
     * Creates an empty helper config with no constraints and no helpers.
     */
    init() {
        visualConstraints = ""
        helperDictionary = [:]
    }
    
    /**
     * Installs this ruler helper config on the given `NSRulerView`. Includes
     * adding all helper views and adding the constraints for those helpers
     * to the ruler view.
     */
    func installOnRuler(ruler: NSRulerView) {
        helperViews.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            ruler.addSubview($0)
        }
        ruler.addConstraints(layoutConstraints)
    }
    
    /**
     * Uninstalls this ruler helper config from the given `NSRulerView`. Includes
     * removing the constraints for the helper views and removing the helper views
     * from the ruler view.
     */
    func uninstallFromRuler(ruler: NSRulerView) {
        ruler.removeConstraints(layoutConstraints)
        helperViews.forEach { $0.removeFromSuperview() }
    }
}