//
//  WKWebView+UserpilotTargeting.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Reads one DOM snapshot asynchronously without replacing the host app navigation delegate.
//

import WebKit

internal extension WKWebView {
    /// Main-thread completion fires once. A failed/unresponsive page contributes no DOM targets.
    /// The timeout releases the callback even if the web process never answers.
    func captureUserpilotElements(clip: CGRect, completion: @escaping ([ElementNode]) -> Void) {
        let originalURL = url
        let originalBounds = convert(bounds, to: nil)
        var pending: (([ElementNode]) -> Void)? = completion
        let finish: ([ElementNode]) -> Void = { nodes in
            let callback = pending
            pending = nil
            callback?(nodes)
        }
        let timeout = DispatchWorkItem { finish([]) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
        evaluateUserpilotScript(WebElementScript.capture) { [weak self, weak originalWindow = window] value in
            guard pending != nil else { return }
            timeout.cancel()
            guard let self, self.window != nil, self.window === originalWindow, self.url == originalURL,
                  self.convert(self.bounds, to: nil) == originalBounds,
                  let value, JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value),
                  let snapshot = try? JSONDecoder().decode(WebElementSnapshot.self, from: data) else {
                finish([])
                return
            }
            // Content below an adjusted inset starts after that inset; .never contributes zero.
            let insets = self.scrollView.adjustedContentInset
            let viewport = originalBounds.inset(by: insets)
            finish(snapshot.nodes(in: self, viewport: viewport, clip: clip))
        }
    }

    /// Whether the page's main vertical scroller is at its end, or nil when nothing on the
    /// page scrolls vertically. Runs in the web process; a failed, late or unreadable reply
    /// counts as not at end. Completes once on main.
    func readUserpilotScrollEnd(completion: @escaping (Bool?) -> Void) {
        var pending: ((Bool?) -> Void)? = completion
        let finish: (Bool?) -> Void = { answer in
            let callback = pending
            pending = nil
            callback?(answer)
        }
        let timeout = DispatchWorkItem { finish(false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
        evaluateUserpilotScript(WebElementScript.scrollEnd) { value in
            guard pending != nil else { return }
            timeout.cancel()
            finish(WebScrollSnapshot.atEnd(from: value))
        }
    }

    /// Runs `script` in the SDK's own JavaScript world on iOS 14+, so page scripts that patch DOM
    /// built-ins cannot change what it reads. Completes on main with the reply, or nil when it failed.
    private func evaluateUserpilotScript(_ script: String, completion: @escaping (Any?) -> Void) {
        guard #available(iOS 14.0, *) else {
            evaluateJavaScript(script) { value, _ in completion(value) }
            return
        }
        evaluateJavaScript(script, in: nil, in: .defaultClient) { result in
            completion(try? result.get())
        }
    }
}
