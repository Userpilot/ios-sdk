//
//  Utils.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

// swiftlint:disable all

func delay(_ delay: Double, closure: @escaping () -> Void) {

    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
        execute: closure)

}

extension Dictionary where Key == String, Value == Any {
    func formattedJSONLabel() -> NSAttributedString {
        let attributedText = NSMutableAttributedString()

        let keyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        ]

        let stringAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemGreen,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]

        let numberAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemOrange,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]

        let punctuationAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]

        func appendFormatted(json: Any, indent: String = "") {
            if let dict = json as? [String: Any] {
                attributedText.append(NSAttributedString(string: "{\n", attributes: punctuationAttributes))
                for (index, key) in dict.keys.enumerated() {
                    attributedText.append(NSAttributedString(string: indent + "  \"\(key)\": ", attributes: keyAttributes))

                    let value = dict[key]

                    // Recursive check
                    if let subDict = value as? [String: Any] {
                        appendFormatted(json: subDict, indent: indent + "  ")
                    } else if let stringValue = value as? String {
                        attributedText.append(NSAttributedString(string: "\"\(stringValue)\"", attributes: stringAttributes))
                    } else if let numberValue = value as? NSNumber {
                        attributedText.append(NSAttributedString(string: "\(numberValue)", attributes: numberAttributes))
                    } else if value is NSNull {
                        attributedText.append(NSAttributedString(string: "null", attributes: punctuationAttributes))
                    } else {
                        attributedText.append(NSAttributedString(string: "\"\(String(describing: value))\"", attributes: stringAttributes))
                    }

                    if index < dict.keys.count - 1 {
                        attributedText.append(NSAttributedString(string: ",", attributes: punctuationAttributes))
                    }

                    // ADD NEW LINE AFTER EACH PROPERTY
                    attributedText.append(NSAttributedString(string: "\n", attributes: punctuationAttributes))
                }
                attributedText.append(NSAttributedString(string: indent + "}", attributes: punctuationAttributes))
            } else {
                // Handle arrays or other values if needed
            }
        }

        appendFormatted(json: self)

        return attributedText
    }
}

// swiftlint:enable all
