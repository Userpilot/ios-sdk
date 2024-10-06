//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit

internal class UPTextView: UILabel {

    // Listener for handling content-related actions such as link clicks.
    private weak var experienceContentProtocol: ExperienceContentProtocol?

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    /// Common initializer for setting up view properties.
    private func initializeView() {
        numberOfLines = 0 // UILabel does not have a direct property for line numbers, but this allows multi-line.
        isUserInteractionEnabled = true // Enable user interaction for link detection
        backgroundColor = .clear
    }

    // MARK: - Setup Methods

    /**
     Configures the label with the provided line data, styling, and listener for
     handling content-related actions.
     
     - Parameters:
     - line: The `Line` object containing the text content and styling information.
     - style: The `ThemeData` that provides styling attributes for the text.
     - experienceContentListener: A listener for handling link clicks.
     */
    func setupView(line: Line, style: ThemeData, experienceContentProtocol: ExperienceContentProtocol) {
        self.experienceContentProtocol = experienceContentProtocol

        let attributedString = NSMutableAttributedString()

        // Process each content item in the line
        line.content?.forEach { content in
            guard let text = content.text else { return }
            let start = attributedString.length
            attributedString.append(NSAttributedString(string: text))
            let end = attributedString.length

            if line.type == .heading {
                // Apply header styles if the line is a heading
                applyHeaderStyles(to: attributedString, line: line, style: style, range: NSRange(start..<end))
            } else {
                // Retrieve text style mark or use a default one
                let textStyleMark = content.marks?.first(where: {
                    $0.type == "textStyle"
                }) ?? ThemeHandler.DefaultValues.defaultTextStyleMark
                applyTextStyle(to: attributedString, mark: textStyleMark, style: style, range: NSRange(start..<end))
            }

            // Apply additional marks (link, bold, italic)
            content.marks?.forEach { mark in
                switch mark.type ?? "" {
                case "link":
                    // Apply link style
                    applyLinkStyle(to: attributedString, mark: mark, range: NSRange(start..<end))
                case "bold":
                    // Apply bold trait to existing font
                    updateFontTrait(for: attributedString, mark: mark, trait: .traitBold, range: NSRange(start..<end))
                case "italic":
                    // Apply italic trait to existing font
                    updateFontTrait(for: attributedString, mark: mark, trait: .traitItalic, range: NSRange(start..<end))
                default:
                    break
                }
            }
        }

        // Set text alignment based on the line attributes
        textAlignment = line.attrs?.textAlign?.textAlignment() ?? .center
        attributedText = attributedString
    }

    // MARK: - Private Helper Methods

    /// Function to apply or update the font trait (bold/italic) for a specified range.
    private func updateFontTrait(for attributedString: NSMutableAttributedString,
                                 mark: Mark,
                                 trait: UIFontDescriptor.SymbolicTraits,
                                 range: NSRange) {
        // Retrieve the current font in the specified range
        let fontSize = CGFloat(mark.attrs?.fontSize ?? Int(ThemeHandler.DefaultValues.normalTextSize))

        // Get the current font and set a new font with the specified size
        let currentFont = attributedString
            .attribute(.font, at: range.location, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: fontSize)

        // Create a new font descriptor by combining the desired trait with the existing traits
        var newDescriptor = currentFont.fontDescriptor
        if let updatedDescriptor = newDescriptor.withSymbolicTraits(newDescriptor.symbolicTraits.union(trait)) {
            newDescriptor = updatedDescriptor
        }

        // Create a new font using the updated descriptor
        let updatedFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)

        // Apply the new font to the specified range
        attributedString.addAttribute(.font, value: updatedFont, range: range)
    }

    /// Function to apply link style.
    private func applyLinkStyle(to attributedString: NSMutableAttributedString, mark: Mark, range: NSRange) {
        // Assuming `mark.attrs?.href` is the URL string.
        if let link = mark.attrs?.href, let url = URL(string: link) {
                // Apply the link attribute to the specified range
                attributedString.addAttribute(.link, value: url, range: range)
                attributedString.addAttribute(.underlineStyle,
                                              value: NSUnderlineStyle.single.rawValue,
                                              range: range)  // Optional underline
                attributedString.addAttribute(.foregroundColor,
                                              value: UIColor.blue,
                                              range: range)  // Optional color
                isUserInteractionEnabled = true  // Enable interaction
                // Add a gesture recognizer to detect link taps
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleLabelTap(_:)))
                addGestureRecognizer(tapGesture)
            }
    }

    /// Function to apply text style (e.g., font size, color) from a Mark to an attributed string.
    private func applyTextStyle(to attributedString: NSMutableAttributedString,
                                mark: Mark,
                                style: ThemeData,
                                range: NSRange) {
        // Set the font size based on the mark's attributes or use a default value
        let fontSize = CGFloat(mark.attrs?.fontSize ?? Int(ThemeHandler.DefaultValues.normalTextSize))

        // Get the current font and set a new font with the specified size
        let currentFont = attributedString
            .attribute(.font, at: range.location, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: fontSize)
        let updatedFont = currentFont.withSize(fontSize)

        // Apply the new font to the specified range
        attributedString.addAttribute(.font, value: updatedFont, range: range)

        let textColor = mark.attrs?.color?.color ?? style.textColor
        attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
    }

    /// Function to apply header styles (e.g., larger font size) for heading lines.
    private func applyHeaderStyles(to attributedString: NSMutableAttributedString,
                                   line: Line,
                                   style: ThemeData,
                                   range: NSRange) {
        let textColor = style.titleTextColor
        let headerFont = line.attrs?.level?.fontSize() ?? ThemeHandler.DefaultValues.headerTextSize
        attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
        attributedString.addAttribute(.font, value: headerFont, range: range)
    }

    // Method to handle link tap
    @objc private func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard let text = attributedText, gesture.state == .ended else { return }

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bounds.size)
        let textStorage = NSTextStorage(attributedString: text)

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let location = gesture.location(in: self)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode

        let index = layoutManager.characterIndex(for: location,
                                                 in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        // Check if the tapped index is within a link's range
        if index < text.length, let link = text.attribute(.link, at: index, effectiveRange: nil) as? URL {
            // Open the link
            UIApplication.shared.open(link)
        }
    }
}
