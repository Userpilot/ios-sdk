//
//  UPExperienceNPSTests.swift
//  Userpilot SDK
//
//  The NPS dismiss chip lightens dark backgrounds, darkens softly near white and darkens fully between.
//

import UIKit
import XCTest
@testable import Userpilot

final class UPExperienceNPSTests: XCTestCase {
    func testBackgroundsBelow64GetALightOverlay() {
        XCTAssertEqual(UPExperienceDismissAction.dismissChipOverlay(brightness: 63.9 / 255),
                       UIColor.white.withAlphaComponent(0.15))
    }

    func testBackgroundsFrom64To217GetTheFullDarkOverlay() {
        XCTAssertEqual(UPExperienceDismissAction.dismissChipOverlay(brightness: 64 / 255),
                       UIColor.black.withAlphaComponent(0.35))
        XCTAssertEqual(UPExperienceDismissAction.dismissChipOverlay(brightness: 217 / 255),
                       UIColor.black.withAlphaComponent(0.35))
    }

    func testBackgroundsAbove217GetTheSoftDarkOverlay() {
        XCTAssertEqual(UPExperienceDismissAction.dismissChipOverlay(brightness: 217.1 / 255),
                       UIColor.black.withAlphaComponent(0.16))
    }
}
