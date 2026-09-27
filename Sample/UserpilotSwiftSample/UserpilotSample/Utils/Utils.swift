//
//  Utils.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

func delay(_ delay: Double, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
        execute: closure
    )
}

enum JSONPreview {

    /// Text attributes per JSON token kind, built once per render.
    private struct Palette {
        let key: [NSAttributedString.Key: Any]
        let string: [NSAttributedString.Key: Any]
        let number: [NSAttributedString.Key: Any]
        let bool: [NSAttributedString.Key: Any]
        let null: [NSAttributedString.Key: Any]
        let punctuation: [NSAttributedString.Key: Any]

        init(fontSize: CGFloat) {
            key = JSONPreview.attributes(color: .systemBlue, size: fontSize, weight: .semibold)
            string = JSONPreview.attributes(color: .systemGreen, size: fontSize, weight: .regular)
            number = JSONPreview.attributes(color: .systemOrange, size: fontSize, weight: .regular)
            bool = JSONPreview.attributes(color: .systemPurple, size: fontSize, weight: .regular)
            null = JSONPreview.attributes(color: .tertiaryLabel, size: fontSize, weight: .regular)
            punctuation = JSONPreview.attributes(color: .label, size: fontSize, weight: .regular)
        }
    }

    static func attributedString(
        from object: Any?,
        fontSize: CGFloat = 12
    ) -> NSAttributedString {
        guard let object else {
            return NSAttributedString(
                string: "null",
                attributes: attributes(color: .tertiaryLabel, size: fontSize, weight: .regular)
            )
        }
        let result = NSMutableAttributedString()
        append(object, to: result, indent: "", palette: Palette(fontSize: fontSize))
        return result
    }

    static func attributedString(
        from dictionary: [String: Any]?,
        fontSize: CGFloat = 12
    ) -> NSAttributedString {
        guard let dictionary, !dictionary.isEmpty else {
            return NSAttributedString(
                string: "{}",
                attributes: attributes(color: .secondaryLabel, size: fontSize, weight: .regular)
            )
        }
        return attributedString(from: dictionary as Any, fontSize: fontSize)
    }

    static func prettyString(from object: Any?) -> String {
        guard let object,
              JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let string = String(data: data, encoding: .utf8)
        else {
            return object.map { String(describing: $0) } ?? "null"
        }
        return string
    }

    // MARK: - Private

    private static func attributes(
        color: UIColor,
        size: CGFloat,
        weight: UIFont.Weight
    ) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: color,
            .font: UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        ]
    }

    private static func append(
        _ json: Any,
        to attributedText: NSMutableAttributedString,
        indent: String,
        palette: Palette
    ) {
        if let dict = json as? [String: Any] {
            appendObject(dict, to: attributedText, indent: indent, palette: palette)
        } else if let array = json as? [Any] {
            appendArray(array, to: attributedText, indent: indent, palette: palette)
        } else {
            appendScalar(json, to: attributedText, palette: palette)
        }
    }

    private static func appendObject(
        _ dict: [String: Any],
        to attributedText: NSMutableAttributedString,
        indent: String,
        palette: Palette
    ) {
        let keys = dict.keys.sorted()
        attributedText.append(NSAttributedString(string: "{", attributes: palette.punctuation))
        guard !keys.isEmpty else {
            attributedText.append(NSAttributedString(string: "}", attributes: palette.punctuation))
            return
        }
        attributedText.append(NSAttributedString(string: "\n", attributes: palette.punctuation))
        for (index, key) in keys.enumerated() {
            attributedText.append(
                NSAttributedString(string: indent + "  \"\(key)\": ", attributes: palette.key)
            )
            if let value = dict[key] {
                append(value, to: attributedText, indent: indent + "  ", palette: palette)
            } else {
                attributedText.append(NSAttributedString(string: "null", attributes: palette.null))
            }
            appendSeparator(to: attributedText, isLast: index == keys.count - 1, palette: palette)
        }
        attributedText.append(NSAttributedString(string: indent + "}", attributes: palette.punctuation))
    }

    private static func appendArray(
        _ array: [Any],
        to attributedText: NSMutableAttributedString,
        indent: String,
        palette: Palette
    ) {
        attributedText.append(NSAttributedString(string: "[", attributes: palette.punctuation))
        guard !array.isEmpty else {
            attributedText.append(NSAttributedString(string: "]", attributes: palette.punctuation))
            return
        }
        attributedText.append(NSAttributedString(string: "\n", attributes: palette.punctuation))
        for (index, value) in array.enumerated() {
            attributedText.append(
                NSAttributedString(string: indent + "  ", attributes: palette.punctuation)
            )
            append(value, to: attributedText, indent: indent + "  ", palette: palette)
            appendSeparator(to: attributedText, isLast: index == array.count - 1, palette: palette)
        }
        attributedText.append(NSAttributedString(string: indent + "]", attributes: palette.punctuation))
    }

    /// The `,` between entries (omitted after the last) plus the line break.
    private static func appendSeparator(
        to attributedText: NSMutableAttributedString,
        isLast: Bool,
        palette: Palette
    ) {
        if !isLast {
            attributedText.append(NSAttributedString(string: ",", attributes: palette.punctuation))
        }
        attributedText.append(NSAttributedString(string: "\n", attributes: palette.punctuation))
    }

    private static func appendScalar(
        _ value: Any,
        to attributedText: NSMutableAttributedString,
        palette: Palette
    ) {
        if value is NSNull {
            attributedText.append(NSAttributedString(string: "null", attributes: palette.null))
        } else if let boolValue = value as? Bool {
            attributedText.append(
                NSAttributedString(string: boolValue ? "true" : "false", attributes: palette.bool)
            )
        } else if let stringValue = value as? String {
            attributedText.append(
                NSAttributedString(string: "\"\(stringValue)\"", attributes: palette.string)
            )
        } else if let numberValue = value as? NSNumber {
            // Distinguish Bool boxed as NSNumber.
            let isBool = CFGetTypeID(numberValue) == CFBooleanGetTypeID()
            attributedText.append(
                NSAttributedString(
                    string: isBool ? (numberValue.boolValue ? "true" : "false") : "\(numberValue)",
                    attributes: isBool ? palette.bool : palette.number
                )
            )
        } else {
            attributedText.append(
                NSAttributedString(string: "\"\(String(describing: value))\"", attributes: palette.string)
            )
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    func formattedJSONLabel(fontSize: CGFloat = 14) -> NSAttributedString {
        JSONPreview.attributedString(from: self, fontSize: fontSize)
    }
}
