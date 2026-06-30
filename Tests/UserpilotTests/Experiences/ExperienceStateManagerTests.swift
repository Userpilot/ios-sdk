//
//  ExperienceStateManagerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all
final class ExperienceStateManagerTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var logger: MockLogger!
    private var stateManager: ExperienceStateManaging!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        logger = MockLogger()
        config.logger = logger
        userpilot = MockUserpilot(config: config)
        stateManager = ExperienceStateManager(container: userpilot.container)
    }

    override func tearDown() {
        stateManager = nil
        logger = nil
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_isIdle() {
        // Assert
        if case .idle = stateManager.getCurrentState() {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected idle state")
        }
        XCTAssertFalse(stateManager.isActive())
        XCTAssertFalse(stateManager.isManualTrigger())
        XCTAssertFalse(stateManager.isPreviewMode())
        XCTAssertFalse(stateManager.hasCachedExperience())
    }

    // MARK: - State Transitions

    func testMarkManualTrigger_setsPendingManualAndBypassesScreenValidation() {
        // Act
        stateManager.markManualTrigger("exp-123")

        // Assert
        if case .pendingManual(let experienceId) = stateManager.getCurrentState() {
            XCTAssertEqual(experienceId, "exp-123")
        } else {
            XCTFail("Expected pendingManual state")
        }
        XCTAssertTrue(stateManager.isManualTrigger())
        XCTAssertTrue(stateManager.shouldBypassScreenValidation())
        XCTAssertTrue(logger.loggedInfos.contains(where: { $0.contains("PendingManual") }))
    }

    func testMarkAutomaticTrigger_setsPendingAutomaticWithoutScreenBypass() {
        // Arrange
        let content = makeExperienceContent()

        // Act
        stateManager.markAutomaticTrigger(content)

        // Assert
        if case .pendingAutomatic(let storedContent) = stateManager.getCurrentState() {
            XCTAssertEqual(storedContent?.experienceId(), content.experienceId())
        } else {
            XCTFail("Expected pendingAutomatic state")
        }
        XCTAssertFalse(stateManager.isManualTrigger())
        XCTAssertFalse(stateManager.shouldBypassScreenValidation())
        XCTAssertTrue(logger.loggedInfos.contains(where: { $0.contains("PendingAutomatic") }))
    }

    func testMarkPreviewMode_setsPendingPreviewAndBypassesScreenValidation() {
        // Act
        stateManager.markPreviewMode()

        // Assert
        if case .pendingPreview = stateManager.getCurrentState() {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected pendingPreview state")
        }
        XCTAssertTrue(stateManager.isPreviewMode())
        XCTAssertTrue(stateManager.shouldBypassScreenValidation())
    }

    func testMarkWaitingDelay_isActiveButNotActivelyRendered() {
        // Act
        stateManager.markWaitingDelay(.manual)

        // Assert
        if case .waitingDelay(let triggerType) = stateManager.getCurrentState() {
            XCTAssertEqual(triggerType, .manual)
        } else {
            XCTFail("Expected waitingDelay state")
        }
        XCTAssertTrue(stateManager.isActive())
        XCTAssertFalse(stateManager.isActivelyRendered())
        XCTAssertTrue(stateManager.isManualTrigger())
    }

    func testMarkActive_storesContentAndTriggerType() {
        // Arrange
        let content = makeExperienceContent()

        // Act
        stateManager.markActive(.automatic, content)

        // Assert
        if case .active(let triggerType, let activeContent) = stateManager.getCurrentState() {
            XCTAssertEqual(triggerType, .automatic)
            XCTAssertEqual(activeContent.experienceId(), content.experienceId())
        } else {
            XCTFail("Expected active state")
        }
        XCTAssertTrue(stateManager.isActive())
        XCTAssertTrue(stateManager.isActivelyRendered())
        XCTAssertEqual(stateManager.getActiveContent()?.experienceId(), content.experienceId())
        XCTAssertEqual(stateManager.getActiveTriggerType(), .automatic)
    }

    func testMarkShowingThankYou_isActiveAndActivelyRendered() {
        // Act
        stateManager.markShowingThankYou()

        // Assert
        if case .showingThankYou = stateManager.getCurrentState() {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected showingThankYou state")
        }
        XCTAssertTrue(stateManager.isActive())
        XCTAssertTrue(stateManager.isActivelyRendered())
    }

    func testMarkCachedManual_setsCachedExperienceId() {
        // Act
        stateManager.markCachedManual("cached-exp")

        // Assert
        if case .cachedPendingManual(let experienceId) = stateManager.getCurrentState() {
            XCTAssertEqual(experienceId, "cached-exp")
        } else {
            XCTFail("Expected cachedPendingManual state")
        }
        XCTAssertTrue(stateManager.hasCachedExperience())
        XCTAssertEqual(stateManager.getCachedExperienceId(), "cached-exp")
    }

    func testMarkCachedAutomatic_setsCachedExperienceContent() {
        // Arrange
        let content = makeExperienceContent()

        // Act
        stateManager.markCachedAutomatic(content)

        // Assert
        if case .cachedPendingAutomatic(let cachedContent) = stateManager.getCurrentState() {
            XCTAssertEqual(cachedContent.experienceId(), content.experienceId())
        } else {
            XCTFail("Expected cachedPendingAutomatic state")
        }
        XCTAssertTrue(stateManager.hasCachedExperience())
        XCTAssertEqual(stateManager.getCachedExperienceContent()?.experienceId(), content.experienceId())
    }

    func testMarkIdle_clearsActiveStateAndComponent() {
        // Arrange
        let content = makeExperienceContent()
        let component = MockExperienceComponent()
        stateManager.markActive(.manual, content)
        stateManager.setActiveComponent(component)

        // Act
        stateManager.markIdle()

        // Assert
        if case .idle = stateManager.getCurrentState() {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected idle state")
        }
        XCTAssertFalse(stateManager.isActive())
        XCTAssertNil(stateManager.getActiveComponent())
    }

    // MARK: - Component Management

    func testSetActiveComponent_storesWeakComponentReference() {
        // Arrange
        let content = makeExperienceContent()
        let component = MockExperienceComponent()
        stateManager.markActive(.manual, content)

        // Act
        stateManager.setActiveComponent(component)

        // Assert
        XCTAssertNotNil(stateManager.getActiveComponent())
        XCTAssertTrue(stateManager.isActiveComponentAlive())
        XCTAssertTrue(logger.loggedInfos.contains(where: { $0.contains("component set") }))
    }

    // MARK: - High-Level Operations

    func testMarkActiveFromCurrentState_usesManualTrigger() {
        // Arrange
        stateManager.markManualTrigger("exp-123")
        let content = makeExperienceContent()

        // Act
        stateManager.markActiveFromCurrentState(content: content)

        // Assert
        XCTAssertEqual(stateManager.getActiveTriggerType(), .manual)
    }

    func testMarkActiveFromCurrentState_usesPreviewTrigger() {
        // Arrange
        stateManager.markPreviewMode()
        let content = makeExperienceContent()

        // Act
        stateManager.markActiveFromCurrentState(content: content)

        // Assert
        XCTAssertEqual(stateManager.getActiveTriggerType(), .preview)
    }

    func testMarkActiveFromCurrentState_defaultsToAutomaticTrigger() {
        // Arrange
        stateManager.markAutomaticTrigger(nil)
        let content = makeExperienceContent()

        // Act
        stateManager.markActiveFromCurrentState(content: content)

        // Assert
        XCTAssertEqual(stateManager.getActiveTriggerType(), .automatic)
    }

    private func makeExperienceContent() -> ExperienceContent {
        .survey(content: MockContentFactory.makeSurveyContent(id: Int.random(in: 1...10_000)))
    }
}

private final class MockExperienceComponent: UPExperience {
    var onTriggerClose: ((Bool) -> Void)?

    func triggerCloseExperience(manualClose: Bool, completion: (() -> Void)?) {
        onTriggerClose?(manualClose)
        completion?()
    }
}
// swiftlint:enable all
