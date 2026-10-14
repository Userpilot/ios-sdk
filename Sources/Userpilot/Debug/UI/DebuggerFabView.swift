//
//  DebuggerFabView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Circular Userpilot logo button. Gestures stay on this view so the panel fade cannot move it.
//

import UIKit

/// Circular Userpilot logo button. Gestures stay on this view so the panel fade cannot move it.
internal final class DebuggerFabView: UIView {

    weak var host: DebugOverlayView?

    private let logoView = UIImageView(image: .userpilotImage(named: "userpilot_debugger_logo"))
    private var downPoint = CGPoint.zero
    private var dragging = false
    private let slop: CGFloat = 8

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DebuggerTheme.brand
        layer.cornerRadius = DebuggerTheme.fabSize / 2
        clipsToBounds = true
        isUserInteractionEnabled = true
        accessibilityLabel = DebuggerStrings.fabAccessibility
        isAccessibilityElement = true
        accessibilityTraits = .button

        logoView.contentMode = .scaleAspectFit
        logoView.isUserInteractionEnabled = false
        addSubview(logoView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        logoView.frame = bounds
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        downPoint = touch.location(in: nil)
        dragging = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: nil)
        let deltaX = point.x - downPoint.x
        let deltaY = point.y - downPoint.y
        if !dragging && (abs(deltaX) > slop || abs(deltaY) > slop) {
            dragging = true
        }
        if dragging {
            downPoint = point
            host?.onFabDragged(deltaX: deltaX, deltaY: deltaY)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(cancelled: true)
    }

    private func finishTouch(cancelled: Bool) {
        if dragging {
            host?.onFabDragEnded()
        } else if !cancelled {
            host?.onFabTapped()
        }
        dragging = false
    }
}
