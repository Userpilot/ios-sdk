//
//  TooltipLayoutObserver.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Tells a waiting tooltip when its host window's layout changes, so a target that is added,
//  shown, moved or faded in without a scroll is searched for again once the screen is quiet.
//

import UIKit

// MARK: - TooltipLayoutObserver

/// Reports layout changes in one host window between `start()` and `stop()`. Main thread only.
///
/// UIKit has no window-wide layout or draw callback and nothing is swizzled, so the window's layer tree
/// is compared with its last signature each time the main run loop goes idle, at most every
/// `sampleInterval`. An idle app costs nothing. Content redrawn inside an unchanged frame, such as new
/// text in a fixed-size label, does not change the signature.
internal final class TooltipLayoutObserver {

    // MARK: Nested Types

    private enum Constants {
        /// Shortest gap between two signatures, so scrolling or an animation costs at most ten walks a second.
        static let sampleInterval: CFTimeInterval = 0.1
        /// After Core Animation's commit, so a signature sees the layout just applied.
        static let observerOrder = CFIndex.max
    }

    // MARK: Properties

    /// Called on the main thread when the window's layout differs from the last signature.
    var onChange: (() -> Void)?

    private let root: () -> UIView?
    private var runLoopObserver: CFRunLoopObserver?
    private var lastSignature: Int?
    private var lastSampledAt: CFTimeInterval = 0

    /// Pending look after activity that the sampling interval skipped.
    private var trailingSample: DispatchWorkItem?

    /// Whether the next idle run loop must sample, because the trailing look is due.
    private var isSampleDue = false

    // MARK: Initialization

    /// - Parameter root: the view whose layer tree is compared, read at each sample.
    init(root: @escaping () -> UIView?) {
        self.root = root
    }

    deinit {
        stop()
    }

    // MARK: Driving

    /// Records the current layout and starts comparing against it. Idempotent.
    func start() {
        guard runLoopObserver == nil else { return }
        lastSignature = root()?.layer.userpilotLayoutSignature()
        lastSampledAt = CACurrentMediaTime()
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, Constants.observerOrder
        ) { [weak self] _, _ in
            self?.runLoopWillWait()
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        runLoopObserver = observer
    }

    /// Stops comparing and drops a pending look. Idempotent.
    func stop() {
        trailingSample?.cancel()
        trailingSample = nil
        isSampleDue = false
        guard let observer = runLoopObserver else { return }
        CFRunLoopObserverInvalidate(observer)
        runLoopObserver = nil
    }

    // MARK: Sampling

    /// The main thread finished a turn of work, which may have changed the layout.
    private func runLoopWillWait() {
        let sinceLastSample = CACurrentMediaTime() - lastSampledAt
        if isSampleDue || sinceLastSample >= Constants.sampleInterval {
            sample()
            return
        }
        guard trailingSample == nil else { return }
        // A change made just before the app went idle would otherwise never be compared. The wake this
        // causes samples here, after the commit, rather than inside the block.
        let workItem = DispatchWorkItem { [weak self] in
            self?.trailingSample = nil
            self?.isSampleDue = true
        }
        trailingSample = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (Constants.sampleInterval - sinceLastSample), execute: workItem
        )
    }

    private func sample() {
        isSampleDue = false
        trailingSample?.cancel()
        trailingSample = nil
        lastSampledAt = CACurrentMediaTime()
        let signature = root()?.layer.userpilotLayoutSignature()
        guard signature != lastSignature else { return }
        lastSignature = signature
        onChange?()
    }
}
