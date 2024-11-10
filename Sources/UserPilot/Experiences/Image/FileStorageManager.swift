//
//  FileStorageManager.swift
//
//
//  Created by Motasem Hamed on 07/11/2024.
//
//  [Brief Description]
//  FileStorageManager provides an implementation of the `FileStoring` protocol,
//  handling image storage operations, including saving, loading, and managing
//  storage size limits for cached images. It ensures that images are saved to the
//  file system and enforces a size limit by evicting excess files.
//

import Foundation
import UIKit

/**
 The `FileStoring` protocol defines the methods necessary
 for managing image file storage, including saving and loading
 images from the file system.

 - Methods:
   - `saveImage(_:withURL:)`: Saves image data to the file system with a specified URL.
   - `loadImage(_:)`: Loads an image from the file system using a URL.
 */
protocol FileStoring {
    /// Saves an image to the file system.
    func saveImage(_ imageData: Data, withURL url: String)

    /// Loads an image from the file system.
    func loadImage(_ url: String) -> UIImage?
}

class FileStorageManager {

    // Directory where files will be stored
    private let storageDirectory: URL
    private let maxStorageSize: Int = 10 * 1024 * 1024

    private let fileManager = FileManager.default

    init(container: DIContainer) {
        guard
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            storageDirectory = URL(fileURLWithPath: "")
            return
        }

        storageDirectory = documentDirectory.appendingPathComponent(FileStorageManager.fileStorageDirectory)
        createDirectoryIfNeeded()
    }

    // Helper function to create the directory if it doesn't exist
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: storageDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil)
            } catch { }
        }
    }
}

// MARK: - FileStoring Protocol Methods

extension FileStorageManager: FileStoring {

    func saveImage(_ imageData: Data, withURL url: String) {
        guard let name = url.getImageNameWithoutExtension() else { return }
        let fileURL = storageDirectory.appendingPathComponent(name)

        createDirectoryIfNeeded()
        do {
            try imageData.write(to: fileURL)
        } catch { }
    }

    func loadImage(_ url: String) -> UIImage? {
        guard let name = url.getImageNameWithoutExtension() else { return nil }
        let fileURL = storageDirectory.appendingPathComponent(name)

        if fileManager.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return nil
    }
}

// MARK: - Size Management & Eviction Methods

extension FileStorageManager {

    private func enforceSizeLimit() {
        let currentSize = getTotalStorageSize()
        if currentSize > maxStorageSize {
            removeExcessFiles(toFitSize: currentSize)
        }
    }

    private func getTotalStorageSize() -> Int64 {
        let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory, includingPropertiesForKeys: nil, options: [])
        var totalSize: Int64 = 0

        files?.forEach { file in
            let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    private func removeExcessFiles(toFitSize currentSize: Int64) {
        let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory, includingPropertiesForKeys: nil, options: [])
        guard let filesList = files else { return }

        var totalSize = currentSize
        var fileDetails: [(URL, Int64)] = []

        for file in filesList {
            let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            fileDetails.append((file, Int64(fileSize)))
        }

        let sortedFiles = fileDetails.sorted { $0.0.lastPathComponent < $1.0.lastPathComponent }

        for (fileURL, _) in sortedFiles {
            if totalSize <= maxStorageSize {
                break
            }

            do {
                let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                totalSize -= Int64(fileSize)
                try fileManager.removeItem(at: fileURL)
            } catch { }
        }
    }

    func deleteFile(withFileName fileName: String) {
        let fileURL = storageDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }
}

// MARK: - Properties

internal extension FileStorageManager {

    // Static constants
    static let fileStorageDirectory = "UserPilotSDKDirectory"
}
