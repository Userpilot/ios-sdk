//
//  CaptureEncoder.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Encodes one confirmed capture's PNG and capture.json in memory and checks the upload size limits.
//

import UIKit

internal protocol CaptureEncoding: AnyObject {
    /// Encodes the PNG and `capture.json` in memory; nothing is written to disk. Fails with `tooLarge`
    /// when either part is over its limit. Retains both inputs until completion, which runs off main.
    func prepareUpload(
        document: CaptureDocument,
        screenshot: UIImage,
        completion: @escaping (Result<CaptureUpload, CaptureEncodingError>) -> Void
    )
}

internal enum CaptureEncodingError: Error, Equatable {
    case screenshotEncodingFailed
    case documentEncodingFailed
    /// The PNG is over `maxScreenshotBytes` or the document over `maxDocumentBytes`; nothing is sent.
    case tooLarge
}

/// Encodes on a private utility queue so PNG compression never blocks main.
internal final class CaptureEncoder: CaptureEncoding {
    private let queue = DispatchQueue(label: Constants.BuilderCapture.encoderQueueLabel, qos: .utility)

    func prepareUpload(
        document: CaptureDocument,
        screenshot: UIImage,
        completion: @escaping (Result<CaptureUpload, CaptureEncodingError>) -> Void
    ) {
        // Capture values, not a weak encoder: an admitted Save finishes even if the instance is released.
        queue.async {
            completion(Self.encode(document: document, screenshot: screenshot))
        }
    }

    /// Compact, key-sorted JSON and the PNG as rendered.
    private static func encode(
        document: CaptureDocument, screenshot: UIImage
    ) -> Result<CaptureUpload, CaptureEncodingError> {
        guard let imageData = screenshot.pngData() else { return .failure(.screenshotEncodingFailed) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let documentData = try? encoder.encode(document) else { return .failure(.documentEncodingFailed) }
        return makeUpload(captureID: document.captureID, screenshot: imageData, document: documentData)
    }

    /// Applies the size limits before anything is sent. A part exactly at its limit is accepted.
    static func makeUpload(
        captureID: String, screenshot: Data, document: Data
    ) -> Result<CaptureUpload, CaptureEncodingError> {
        guard screenshot.count <= Constants.BuilderCapture.Upload.maxScreenshotBytes,
              document.count <= Constants.BuilderCapture.Upload.maxDocumentBytes else {
            return .failure(.tooLarge)
        }
        return .success(CaptureUpload(captureID: captureID, screenshot: screenshot, document: document))
    }
}
