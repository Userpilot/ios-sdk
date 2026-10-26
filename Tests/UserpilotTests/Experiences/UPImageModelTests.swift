//
//  UPImageModelTests.swift
//  Userpilot SDK
//
//  An image downloads while a view shows it, like SwiftUI's `.task`: it starts on the first
//  appearance, stops when the last view goes away or the model is released, and never repeats once done.
//

import XCTest
@testable import Userpilot

final class UPImageModelTests: XCTestCase {
    private let size = CGSize(width: 100, height: 50)
    private let pixel = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    func testCreatingTheModelStartsNoDownload() {
        let loader = MockImageLoader()
        _ = UPImageModel(url: "a", blurHash: nil, size: size, loader: loader)
        XCTAssertTrue(loader.tasks.isEmpty)
    }

    func testCachedImageIsReadyAtOnceAndNeedsNoDownload() {
        let loader = MockImageLoader()
        loader.cachedImages["a"] = pixel
        let model = UPImageModel(url: "a", blurHash: nil, size: size, loader: loader)
        XCTAssertNotNil(model.image)
        model.viewAppeared()
        XCTAssertTrue(loader.tasks.isEmpty)
    }

    func testFirstAppearanceStartsOneDownload() {
        let loader = MockImageLoader()
        let model = UPImageModel(url: "a", blurHash: nil, size: size, loader: loader)
        XCTAssertTrue(loader.tasks.isEmpty)
        model.viewAppeared()
        model.viewAppeared()
        XCTAssertEqual(loader.tasks.count, 1, "A second view showing the same image shares the download.")
    }

    func testDownloadStopsWhenTheLastViewDisappears() {
        let loader = MockImageLoader()
        let model = UPImageModel(url: "a", blurHash: nil, size: size, loader: loader)
        model.viewAppeared()
        model.viewAppeared()
        model.viewDisappeared()
        XCTAssertEqual(loader.tasks.count, 1)
        guard loader.tasks.count == 1 else { return }
        XCTAssertFalse(loader.tasks[0].isCancelled, "Another view still shows the image.")
        model.viewDisappeared()
        XCTAssertTrue(loader.tasks[0].isCancelled)
    }

    func testReappearingRestartsAnUnfinishedDownload() {
        let loader = MockImageLoader()
        let model = UPImageModel(url: "a", blurHash: nil, size: size, loader: loader)
        model.viewAppeared()
        model.viewDisappeared()
        model.viewAppeared()
        XCTAssertEqual(loader.tasks.count, 2)
        guard loader.tasks.count == 2 else { return }
        XCTAssertTrue(loader.tasks[0].isCancelled)
        XCTAssertFalse(loader.tasks[1].isCancelled)
    }

    func testReleasingTheModelStopsItsDownload() {
        let loader = MockImageLoader()
        var model: UPImageModel? = UPImageModel(url: "a", blurHash: nil, size: size, loader: loader)
        model?.viewAppeared()
        XCTAssertEqual(loader.tasks.count, 1)
        guard loader.tasks.count == 1 else { return }
        model = nil
        XCTAssertTrue(loader.tasks[0].isCancelled, "Closing the experience releases the model and stops its download.")
    }

    func testFinishedImageIsNotDownloadedAgain() {
        let loader = MockImageLoader()
        loader.onLoad = { [pixel] _, _, _ in pixel }
        let model = UPImageModel(url: "a", blurHash: nil, size: size, loader: loader)
        XCTAssertTrue(loader.tasks.isEmpty)
        model.viewAppeared()
        let loaded = expectation(for: NSPredicate { _, _ in model.image != nil }, evaluatedWith: nil)
        wait(for: [loaded], timeout: 2)
        model.viewDisappeared()
        model.viewAppeared()
        XCTAssertEqual(loader.tasks.count, 1)
    }
}
