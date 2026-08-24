//
//  DebugOverlayViewController.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import ObjectiveC
import UIKit

/// Untracked host for the debugger overlay. Defers status-bar style to the app.
internal final class DebugOverlayViewController: UIViewController {

    private let eventStore: DebugEventStoring
    private let configFactory: DebugConfigSnapshotMaking
    private let userFactory: DebugUserSnapshotMaking

    init(
        eventStore: DebugEventStoring,
        configFactory: DebugConfigSnapshotMaking,
        userFactory: DebugUserSnapshotMaking
    ) {
        self.eventStore = eventStore
        self.configFactory = configFactory
        self.userFactory = userFactory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        objc_setAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey,
            true,
            .OBJC_ASSOCIATION_RETAIN
        )
        view = DebugOverlayView(
            frame: UIScreen.main.bounds,
            eventStore: eventStore,
            configFactory: configFactory,
            userFactory: userFactory
        )
        view.backgroundColor = .clear
    }

    override var prefersStatusBarHidden: Bool {
        false
    }
}
