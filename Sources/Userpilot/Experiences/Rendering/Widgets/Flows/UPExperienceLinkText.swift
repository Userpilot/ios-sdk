//
//  UPExperienceLinkText.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  A plain UITextView for flow lines that contain links; only link glyphs take touches.
//

import SwiftUI

/// A non-editable, non-scrolling `UITextView` that only claims touches on link glyphs.
internal struct UPExperienceLinkText: UIViewRepresentable {
    let string: NSAttributedString
    var isHeading = false

    func makeUIView(context: Context) -> LinkTextView { LinkTextView() }

    func updateUIView(_ view: LinkTextView, context: Context) {
        if view.attributedText != string { view.attributedText = string }
        if isHeading {
            view.accessibilityTraits.insert(.header)
        } else {
            view.accessibilityTraits.remove(.header)
        }
    }

    /// iOS 13 representables have no proposed-size callback, so the parent pins the measured height.
    static func height(of string: NSAttributedString, width: CGFloat) -> CGFloat {
        sizingView.attributedText = string
        return ceil(sizingView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }

    // One off-screen view measures every link line.
    private static let sizingView = LinkTextView()

    final class LinkTextView: UITextView, UITextViewDelegate {
        // Replaceable so tests can catch the opened URL.
        var openURL: (URL) -> Void = { UIApplication.shared.open($0) }

        init() {
            // Explicit TextKit 1 storage so glyph hit-testing behaves the same on every iOS version.
            let storage = NSTextStorage()
            let layout = NSLayoutManager()
            storage.addLayoutManager(layout)
            let container = NSTextContainer(size: .zero)
            container.widthTracksTextView = true
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            super.init(frame: .zero, textContainer: container)
            isEditable = false
            isScrollEnabled = false
            isSelectable = true
            backgroundColor = .clear
            textContainerInset = .zero
            // Today's UILabel draws link glyphs in the link colour over the run's pure blue underline.
            linkTextAttributes = [
                .foregroundColor: UIColor.link,
                .underlineColor: UIColor.blue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            // Like the label it replaces: no dragging a link out (on by default on iPad).
            textDragInteraction?.isEnabled = false
            delegate = self
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        /// Links still open on tap, but a double-tap or long press can't select text or show the edit menu.
        override var canBecomeFirstResponder: Bool { false }

        /// Touches away from a link fall through to the carousel and SwiftUI, as on plain text.
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            super.point(inside: point, with: event) && link(at: point) != nil
        }

        func link(at point: CGPoint) -> URL? {
            guard textStorage.length > 0 else { return nil }
            let glyph = layoutManager.glyphIndex(for: point, in: textContainer)
            let bounds = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
            guard bounds.contains(point) else { return nil }
            let index = layoutManager.characterIndexForGlyph(at: glyph)
            return textStorage.attribute(.link, at: index, effectiveRange: nil) as? URL
        }

        /// A tap opens the link like today's label; long-press preview and menus stay off.
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange,
                      interaction: UITextItemInteraction) -> Bool {
            if interaction == .invokeDefaultAction { openURL(URL) }
            return false
        }
    }
}
