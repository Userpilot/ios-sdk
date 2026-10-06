//
//  String+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 27/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  `String+Extension` contains extensions with helper methods for the `String` class.
//  These extensions provide additional functionality for checking if strings and optional strings are not empty.
//

import Foundation
import UIKit

internal extension Optional where Wrapped == String {

    // Function to return empty state
    var isNotEmpty: Bool {
        return !(self?.isEmpty ?? true)
    }

    func orEmpty() -> String {
        return self ?? ""
    }
}

internal extension String {

    // Function to return empty state
    var isNotEmpty: Bool {
        return !isEmpty
    }

    // Function to trim space in string
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Function to return base url from full domain
    func baseURL() -> String? {
        guard
            let urlComponents = URLComponents(string: self),
            let scheme = urlComponents.scheme,
            let host = urlComponents.host
        else { return nil }
        return "\(scheme)://\(host)"
    }

    // Function to return font size
    var toFontSize: CGFloat {
        if self.contains("px"), let value = Int(self.dropLast(2)) {
            return CGFloat(value)
        } else if let value = Int(self) {
            return CGFloat(value)
        } else {
            return CGFloat(ThemeHandler.DefaultValues.normalTextSize)
        }
    }

    // Function to return size
    var toSize: CGFloat? {
        if self.contains("px"), let value = Int(self.dropLast(2)) {
            return CGFloat(value)
        } else if let value = Int(self) {
            return CGFloat(value)
        } else {
            return nil
        }
    }

    // Function to return RTL language
    var isRTL: Bool {
        let rtlLanguages = ["ar", "arc", "dv", "fa", "ha", "he", "khw", "ks", "ku", "ps", "ur", "yi", "iw", "ji"]
        return rtlLanguages.contains(self)
    }

    // Function to return label height
    func height(withFont font: UIFont, width: CGFloat) -> CGFloat {
        let maxSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        let boundingBox = self.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return ceil(boundingBox.height)
    }

    // Function to return image name
    func getImageNameWithoutExtension() -> String? {
        guard let url = URL(string: self) else { return nil }
        return url.deletingPathExtension().lastPathComponent
    }

    /// Analytics events are the ones that flow through the serialized event queue.
    /// Their socket ACK advances the queue; SDK/content events must not.
    func isAnalyticsEvent() -> Bool {
        return self == Constants.Event.identifyEvent ||
        self == Constants.Event.screenEvent ||
        self == Constants.Event.trackEvent ||
        self == Constants.Event.autoCaptureEvent
    }

}

// MARK: - Json converter

internal extension String {
    /// Decodes a JSON object without accepting scalar or array roots; invalid input stays absent.
    func toJSONDictionary() -> [String: Any]? {
        guard let jsonData = data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: jsonData, options: [])) as? [String: Any]
    }

    /**
    Decodes model JSON strings using `JSONDecoder`, like `toObject` on Android.
    An empty string is `nil`, and a failure is logged through `logger`
    with its reason and coding path, then `nil`, so each caller keeps its own fallback.

    - Parameter logger: Receives the decoding failure; pass the owning instance's logger.
    - Returns: An optional instance of the specified type if decoding is successful, or `nil` if decoding fails.
    */
    func toObject<T: Decodable>(logger: Logging? = nil) -> T? {
        guard !isEmpty else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: Data(self.utf8))
        } catch {
            logger?.error(
                "‼️ Failed to decode %{public}@: %{public}@", String(describing: T.self), error.decodingDiagnostic
            )
            return nil
        }
    }
}

private extension Error {
    /// The failure's reason and coding path, e.g. `typeMismatch String at mobile_contents.steps.0.type: …`.
    var decodingDiagnostic: String {
        guard let decodingError = self as? DecodingError else { return localizedDescription }
        switch decodingError {
        case .dataCorrupted(let context):
            return "dataCorrupted \(context.diagnostic)"
        case .keyNotFound(let key, let context):
            return "keyNotFound '\(key.stringValue)' \(context.diagnostic)"
        case .typeMismatch(let type, let context):
            return "typeMismatch \(type) \(context.diagnostic)"
        case .valueNotFound(let type, let context):
            return "valueNotFound \(type) \(context.diagnostic)"
        @unknown default:
            return String(describing: decodingError)
        }
    }
}

private extension DecodingError.Context {
    var diagnostic: String {
        let path = codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        return "at \(path.isEmpty ? "root" : path): \(debugDescription)"
    }
}
