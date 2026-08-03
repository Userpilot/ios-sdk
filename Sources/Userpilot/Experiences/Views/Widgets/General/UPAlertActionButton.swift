//
//  UPAlertActionButton.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A button that behaves like a row in a system alert: the whole row fills while it is held, and
//  nothing about it is rounded or inset.
//
//  `UPButtonView` — the SDK's button everywhere else — shrinks and dims instead, which is right for a
//  filled CTA sitting inside a card and wrong here: an alert action is a full-bleed row divided from
//  its neighbours by hairlines, and scaling it detaches it from those dividers.
//

import UIKit

internal final class UPAlertActionButton: UIButton {

    /// Fill drawn while the row is held down.
    ///
    /// A translucent overlay rather than a fixed grey, so it works over the material, over a dark
    /// themed card and over the legacy grey gradient without three separate values. The system's own
    /// highlight is similarly subtle — it reads as the row responding, not as a new colour.
    private var highlightFill: UIColor {
        prefersLightContent
            ? UIColor.white.withOpacity(0.12)
            : UIColor.black.withOpacity(0.06)
    }

    /// Whether the surface behind this row is dark, which decides the highlight's direction.
    var prefersLightContent = false

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            // Instant on the way in, brief fade on the way out — the asymmetry the system uses, so a
            // quick tap still registers visibly instead of being swallowed by a symmetric animation.
            let apply = { self.backgroundColor = self.isHighlighted ? self.highlightFill : .clear }
            if isHighlighted {
                apply()
            } else {
                UIView.animate(withDuration: 0.15, animations: apply)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        // This widget lays out with frames.
        translatesAutoresizingMaskIntoConstraints = true
        backgroundColor = .clear
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.8
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
