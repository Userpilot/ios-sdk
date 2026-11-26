//
//  DebuggerOverlayView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Full-screen passthrough overlay: dim + sheet + FAB as siblings so the FAB never jumps.
//

import UIKit

/// Full-screen passthrough overlay: dim + sheet + FAB as siblings so the FAB never jumps.
internal final class DebuggerOverlayView: UIView {

    var onExitRequested: (() -> Void)?

    let fabView = DebuggerFabView()

    private let dimView = UIView()
    private let panelView: DebuggerPanelView
    private var expanded = false
    private var fabOrigin: CGPoint?
    private var dockedRight = true
    private var lastSize: CGSize = .zero

    init(
        frame: CGRect,
        eventStore: DebugEventStoring,
        configFactory: DebugConfigSnapshotMaking,
        userFactory: DebugUserSnapshotMaking
    ) {
        self.panelView = DebuggerPanelView(
            eventStore: eventStore,
            configFactory: configFactory,
            userFactory: userFactory
        )
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true

        dimView.backgroundColor = DebuggerTheme.dim
        dimView.alpha = 0
        dimView.isUserInteractionEnabled = false
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))

        panelView.alpha = 0
        panelView.isUserInteractionEnabled = false
        panelView.onDismissRequested = { [weak self] in
            self?.hidePanel(animated: true)
        }

        fabView.host = self
        addSubview(dimView)
        addSubview(panelView)
        addSubview(fabView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPanel(animated: Bool) {
        expanded = true
        dimView.isUserInteractionEnabled = true
        panelView.isUserInteractionEnabled = true
        panelView.onShown()
        let apply = {
            self.dimView.alpha = 1
            self.panelView.alpha = 1
        }
        setPanelAlpha(animated: animated, apply: apply)
    }

    func hidePanel(animated: Bool) {
        expanded = false
        panelView.onHidden()
        let apply = {
            self.dimView.alpha = 0
            self.panelView.alpha = 0
        }
        // Interaction follows current state; no old fade completion can disable a reopened panel.
        dimView.isUserInteractionEnabled = false
        panelView.isUserInteractionEnabled = false
        setPanelAlpha(animated: animated, apply: apply)
    }

    private func setPanelAlpha(animated: Bool, apply: @escaping () -> Void) {
        if animated {
            UIView.animate(
                withDuration: DebuggerTheme.fadeDuration,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: apply
            )
        } else {
            dimView.layer.removeAllAnimations()
            panelView.layer.removeAllAnimations()
            fabView.layer.removeAllAnimations()
            apply()
        }
    }

    func onFabExitRequested() {
        onExitRequested?()
    }

    func onFabTapped() {
        if expanded {
            hidePanel(animated: true)
        } else {
            showPanel(animated: true)
        }
    }

    func onFabDragged(deltaX: CGFloat, deltaY: CGFloat) {
        guard var origin = fabOrigin else { return }
        origin.x += deltaX
        origin.y += deltaY
        fabOrigin = origin
        fabView.frame.origin = origin
    }

    func onFabDragEnded() {
        let snapped = DebuggerFabDocking.snappedOrigin(
            current: fabOrigin ?? fabView.frame.origin,
            bounds: bounds,
            safeArea: safeAreaInsets
        )
        fabOrigin = snapped
        dockedRight = snapped.x + DebuggerFabDocking.size.width / 2 >= bounds.midX
        UIView.animate(withDuration: DebuggerTheme.fadeDuration) {
            self.fabView.frame.origin = snapped
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dimView.frame = bounds
        layoutPanel()
        layoutFab()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if fabView.frame.contains(point) {
            let local = convert(point, to: fabView)
            if let hit = fabView.hitTest(local, with: event) {
                return hit
            }
        }
        guard expanded else { return nil }
        let hit = super.hitTest(point, with: event)
        if hit === self { return nil }
        return hit
    }

    @objc private func dimTapped() {
        hidePanel(animated: true)
    }

    private func layoutPanel() {
        let inset = safeAreaInsets
        let left = DebuggerTheme.panelMargin + inset.left
        let right = DebuggerTheme.panelMargin + inset.right
        let bottom = DebuggerTheme.panelMargin + inset.bottom
        let height = max((bounds.height - bottom) * DebuggerTheme.panelHeightFraction, 0)
        panelView.frame = CGRect(
            x: left,
            y: bounds.height - bottom - height,
            width: max(bounds.width - left - right, 0),
            height: height
        )
    }

    private func layoutFab() {
        let size = DebuggerTheme.fabSize
        if fabOrigin == nil {
            fabOrigin = DebuggerFabDocking.initialOrigin(bounds: bounds, safeArea: safeAreaInsets)
            dockedRight = true
        } else if lastSize != .zero && lastSize != bounds.size {
            let currentY = fabOrigin?.y ?? 0
            fabOrigin = DebuggerFabDocking.dockedOrigin(
                dockedRight: dockedRight,
                originY: currentY * (bounds.height / max(lastSize.height, 1)),
                bounds: bounds,
                safeArea: safeAreaInsets
            )
        }
        lastSize = bounds.size
        if let origin = fabOrigin {
            fabView.frame = CGRect(origin: origin, size: size)
        }
    }
}
