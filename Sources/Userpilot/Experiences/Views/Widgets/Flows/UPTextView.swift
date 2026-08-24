//
//  UPTextView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//
//  [Brief Description]
//  A custom UILabel subclass that supports attributed text with various styles
//  and link handling. This label is designed to render dynamic content with
//  configurable styles and responds to user interactions for link clicks.
//

import Foundation
import UIKit

internal class UPTextView: UILabel {

    // MARK: - Initializers

    /// Initializes the label with a specified frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    /// Initializes the label from a storyboard or XIB file.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    /// Common initializer for setting up view properties.
    private func initializeView() {
        translatesAutoresizingMaskIntoConstraints = false
        numberOfLines = 0
        isUserInteractionEnabled = true
        backgroundColor = .clear
    }

    // MARK: - Setup Methods

    /**
     Configures the label with the provided line data, styling, and listener for
     handling content-related actions.
     
     - Parameters:
       - line: The `Line` object containing the text content and styling information.
       - theme: The `ExperienceTheme` that provides styling attributes for the text.
       - alignmentDefault: What to align to when `line` carries no `text_align`. Required rather
         than defaulted so a new call site has to state which behaviour it wants; ask the flow via
         ``UPTextAlignmentDefault/forFlow(resolver:isRTL:)``.
     */
    func setupView(
        line: Line,
        theme: ExperienceTheme,
        alignmentDefault: UPTextAlignmentDefault
    ) {
        let attributedString = NSMutableAttributedString()

        // Process each content item in the line
        line.content?.forEach { content in
            guard let text = content.text else { return }
            let start = attributedString.length
            attributedString.append(NSAttributedString(string: text))
            let end = attributedString.length

            if line.type == .heading {
                // Apply header styles if the line is a heading
                applyHeaderStyles(to: attributedString, line: line, theme: theme, range: NSRange(start..<end))
            } else {
                applyTextStyle(to: attributedString, marks: content.marks ?? [],
                               theme: theme, range: NSRange(start..<end))
            }

            // Apply additional marks (link, bold, italic)
            if let linkMark = content.marks?.first(where: { $0.type == ThemeHandler.StyleName.textLink }) {
                applyLinkStyle(to: attributedString, mark: linkMark, range: NSRange(start..<end))
            }
        }

        // Set text alignment based on the line attributes, falling back to the flow's default when
        // the content does not specify one. An explicit value still wins, and still means the
        // absolute edge it always did. The paragraph style has to carry the same alignment:
        // `UILabel` measures attributed text from that, not from `textAlignment`, and a mismatch
        // after the leading-edge default made slide-out sheets report a huge intrinsic height.
        let alignment = line.attrs?.textAlign?.textAlignment() ?? alignmentDefault.resolved
        textAlignment = alignment
        if attributedString.length > 0 {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            attributedString.addAttribute(
                .paragraphStyle,
                value: paragraph,
                range: NSRange(location: 0, length: attributedString.length)
            )
        }
        attributedText = attributedString
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
        }
    }

    // MARK: - Private Helper Methods

    /// Function to apply text style (e.g., font size, color) from a Mark to an attributed string.
    private func applyTextStyle(
        to attributedString: NSMutableAttributedString,
        marks: [Mark],
        theme: ExperienceTheme,
        range: NSRange
    ) {
        // Retrieve text style mark or use a default one
        let textStyleMark = marks.first(where: { $0.type == ThemeHandler.StyleName.textStyle })
        let fontSize = textStyleMark?.attrs?.fontSize?.toFontSize ?? CGFloat(ThemeHandler.DefaultValues.normalTextSize)
        let textColor = textStyleMark?.attrs?.color?.color ?? theme.textColor

        var traits = [UIFontDescriptor.SymbolicTraits]()
        if marks.first(where: { $0.type == ThemeHandler.StyleName.textBold }) != nil {
            traits.append(.traitBold)
        }
        if marks.first(where: { $0.type == ThemeHandler.StyleName.textItalic }) != nil {
            traits.append(.traitItalic)
        }
        let font = UIFont.matching(fontName: theme.fontFamily, fontWeight: traits, fontSize: fontSize)

        attributedString.addAttribute(.font, value: font, range: range)
        attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
    }

    /// Function to apply header styles (e.g., larger font size) for heading lines.
    private func applyHeaderStyles(
        to attributedString: NSMutableAttributedString,
        line: Line,
        theme: ExperienceTheme,
        range: NSRange
    ) {
        let textColor = theme.titleTextColor
        let headerFont = line.attrs?.level?.fontSize() ?? ThemeHandler.DefaultValues.headerTextSize
        let font = UIFont.matching(fontName: theme.fontFamily, fontWeight: [.traitBold], fontSize: CGFloat(headerFont))

        attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
        attributedString.addAttribute(.font, value: font, range: range)
    }

    /// Function to apply link style.
    private func applyLinkStyle(
        to attributedString: NSMutableAttributedString,
        mark: Mark,
        range: NSRange
    ) {
        if let link = mark.attrs?.href, let url = URL(string: link) {
            attributedString.addAttribute(.link, value: url, range: range)
            attributedString.addAttribute(.underlineStyle,
                                          value: NSUnderlineStyle.single.rawValue,
                                          range: range)
            attributedString.addAttribute(.foregroundColor,
                                          value: UIColor.blue,
                                          range: range)
            isUserInteractionEnabled = true

            // Add tap gesture for the link
            let tapGesture = LinkTapGestureRecognizer(target: self, action: #selector(handleLabelTap(_:)))
            tapGesture.range = range
            tapGesture.link = URL(string: mark.attrs?.href ?? "")
            addGestureRecognizer(tapGesture)
        }
    }

    /// Handles link tap.
    @objc private func handleLabelTap(_ gesture: LinkTapGestureRecognizer) {
        guard
            gesture.state == .ended,
            let attributedText = attributedText,
            let range = gesture.modifiedRange,
            let link = gesture.link
        else { return }

        // Create text system objects
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bounds.size)
        let textStorage = NSTextStorage(attributedString: attributedText)

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode

        // Calculate the bounding rect of the rendered text
        let textBoundingRect = layoutManager.usedRect(for: textContainer)

        // Get the location of the tap
        var location = gesture.location(in: self)

        // Adjust x-origin based on alignment
        switch textAlignment {
        case .center:
            location.x -= (bounds.width - textBoundingRect.width) / 2
        case .right where UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft,
             .natural where UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft:
            location.x -= (bounds.width - textBoundingRect.width)
        default:
            break // left aligned or default
        }

        // Get tapped character index
        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        // Validate index in range
        if characterIndex >= range.location,
           characterIndex <= range.location + range.length {
            UIApplication.shared.open(link)
        }
    }

}

// Custom Gesture Recognizer to hold the link
private class LinkTapGestureRecognizer: UITapGestureRecognizer {
    var range: NSRange?
    var link: URL?

    var safeLength: Int {
        return range?.length ?? 0
    }

    var modifiedRange: NSRange? {
        return NSRange(location: range?.location ?? 0, length: safeLength)
    }
}
