//
//  MultipartFormBody.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Builds a multipart/form-data request body from text fields and file parts.
//

import Foundation

/// A `multipart/form-data` body. Field names are SDK-owned constants; values are written as UTF-8.
internal struct MultipartFormBody {
    let boundary: String
    private var parts = Data()

    init(boundary: String = "Userpilot-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    /// The request's `Content-Type` header value.
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// Adds one text field.
    mutating func append(field name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }

    /// Adds one file part with its own content type.
    mutating func append(file name: String, fileName: String, contentType: String, data: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        parts.append(data)
        append("\r\n")
    }

    /// The complete body, closed with the final boundary.
    func encoded() -> Data {
        var body = parts
        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }

    private mutating func append(_ text: String) {
        parts.append(Data(text.utf8))
    }
}
