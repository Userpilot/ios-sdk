//
//  ScreenScrollState.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Whether the screen is at its end, so a missing tooltip target can be reported as
//  `not_found`. Main-thread only.
//

import UIKit
import WebKit

/// A visible vertical scroller. `readAtEnd` answers whether it is at its end, or nil when
/// it turns out not to scroll (a page with no vertical scroller). Completes on main.
internal struct ScrollArea {
    let visibleArea: CGFloat
    let readAtEnd: (@escaping (Bool?) -> Void) -> Void
}

/// The main scroll area is the vertical scroller covering the largest part of the visible
/// screen. The screen is at its end when it cannot scroll further down, or when nothing
/// visible scrolls vertically. Horizontal scrollers (carousels, pagers) are ignored.
///
/// The walk visits only shown views on screen and runs only after a tooltip search found
/// nothing, so a screen that shows its tooltip never pays for it. A WebView page answers
/// through one short script in the web process.
internal enum ScreenScrollState {

    /// Reads every visible vertical scroller in `window` and asks the main one.
    static func isAtEnd(in window: UIWindow, completion: @escaping (Bool) -> Void) {
        var areas: [ScrollArea] = []
        collectVerticalScrollAreas(from: window, clippedTo: window.bounds, into: &areas)
        isAtEnd(areas, completion: completion)
    }

    /// The main scroll area decides: the one with the largest visible area that scrolls. A tie
    /// keeps the outer one, found first. With no scroller, the screen is at its end.
    static func isAtEnd(_ areas: [ScrollArea], completion: @escaping (Bool) -> Void) {
        let ordered = areas.enumerated().sorted {
            $0.element.visibleArea == $1.element.visibleArea
                ? $0.offset < $1.offset
                : $0.element.visibleArea > $1.element.visibleArea
        }
        ask(ordered.map(\.element)[...], completion: completion)
    }

    /// Whether the scroll view's content, including its bottom inset, can move further than
    /// its own height. Only such a view counts as a vertical scroller.
    static func scrollsVertically(_ scrollView: UIScrollView) -> Bool {
        let insets = scrollView.adjustedContentInset
        return scrollView.isScrollEnabled
            && scrollView.contentSize.height + insets.top + insets.bottom > scrollView.bounds.height + 1
    }

    /// Whether the bottom of the content, including its bottom inset, is in view.
    static func isAtEnd(_ scrollView: UIScrollView) -> Bool {
        scrollView.contentOffset.y + scrollView.bounds.height
            >= scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - 1
    }

    private static func ask(_ areas: ArraySlice<ScrollArea>, completion: @escaping (Bool) -> Void) {
        guard let area = areas.first else { completion(true); return }
        area.readAtEnd { atEnd in
            if let atEnd {
                completion(atEnd)
            } else {
                ask(areas.dropFirst(), completion: completion)
            }
        }
    }

    private static func collectVerticalScrollAreas(
        from view: UIView, clippedTo clipBounds: CGRect, into areas: inout [ScrollArea]
    ) {
        guard !view.isHidden, view.alpha > 0.01 else { return }
        let frame = view.convert(view.bounds, to: nil)
        let visible = frame.intersection(clipBounds)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return }
        let area = visible.width * visible.height

        // The page answers for a web view, including its in-page scrollers.
        if let webView = view as? WKWebView {
            areas.append(ScrollArea(visibleArea: area) { [weak webView] completion in
                guard let webView else { completion(false); return }
                webView.readUserpilotScrollEnd(completion: completion)
            })
            return
        }
        if let scrollView = view as? UIScrollView, scrollsVertically(scrollView) {
            areas.append(ScrollArea(visibleArea: area) { [weak scrollView] completion in
                completion(scrollView.map(isAtEnd) ?? false)
            })
        }
        let childClip = view.clipsToBounds ? visible : clipBounds
        view.subviews.forEach { collectVerticalScrollAreas(from: $0, clippedTo: childClip, into: &areas) }
    }
}
