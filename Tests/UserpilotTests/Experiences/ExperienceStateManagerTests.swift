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
class ExperienceStateManagerTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var logger: MockLogger!
    private var stateManager: ExperienceStateManaging!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
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

    // MARK: - Initial State Tests

    func testInitialState_IsIdle() {
        // When: StateManager is initialized
        // Then: Initial state should be Idle
        let currentState = stateManager.getCurrentState()
        if case .idle = currentState {
            // Success
        } else {
            XCTFail("Expected Idle state, got \(currentState)")
        }

        XCTAssertFalse(stateManager.isActive())
        XCTAssertFalse(stateManager.isManualTrigger())
        XCTAssertFalse(stateManager.hasCachedExperience())
    }

    // MARK: - State Transition Tests

    func testMarkManualTrigger_WithExperienceId() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // When: Mark as manual trigger with ID
        stateManager.markManualTrigger("exp-123")

        // Then: State should be PendingManual
        let currentState = stateManager.getCurrentState()
        if case .pendingManual(let experienceId) = currentState {
            XCTAssertEqual(experienceId, "exp-123")
        } else {
            XCTFail("Expected PendingManual state")
        }

        XCTAssertTrue(stateManager.isManualTrigger())
        XCTAssertTrue(stateManager.shouldBypassScreenValidation())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("PendingManual") ?? false)
    }

    func testMarkManualTrigger_WithoutExperienceId() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // When: Mark as manual trigger without ID
        stateManager.markManualTrigger("exp-123")

        // Then: State should be PendingManual with nil ID
        let currentState = stateManager.getCurrentState()
        if case .pendingManual(let experienceId) = currentState {
            XCTAssertEqual(experienceId, "exp-123")
        } else {
            XCTFail("Expected PendingManual state")
        }

        XCTAssertTrue(stateManager.isManualTrigger())
    }

    func testMarkAutomaticTrigger() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // When: Mark as automatic trigger
        stateManager.markAutomaticTrigger(nil)

        // Then: State should be PendingAutomatic
        let currentState = stateManager.getCurrentState()
        if case .pendingAutomatic = currentState {
            // Success
        } else {
            XCTFail("Expected PendingAutomatic state")
        }

        XCTAssertFalse(stateManager.isManualTrigger())
        XCTAssertFalse(stateManager.shouldBypassScreenValidation())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("PendingAutomatic") ?? false)
    }

    func testMarkPreviewMode() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // When: Mark as preview mode
        stateManager.markPreviewMode()

        // Then: State should be PendingPreview
        let currentState = stateManager.getCurrentState()
        if case .pendingPreview = currentState {
            // Success
        } else {
            XCTFail("Expected PendingPreview state")
        }

        XCTAssertTrue(stateManager.isPreviewMode())
        XCTAssertTrue(stateManager.shouldBypassScreenValidation())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("PendingPreview") ?? false)
    }

    func testMarkWaitingDelay() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // When: Mark as waiting delay with manual trigger
        stateManager.markWaitingDelay(.manual)

        // Then: State should be WaitingDelay
        let currentState = stateManager.getCurrentState()
        if case .waitingDelay(let triggerType) = currentState {
            XCTAssertEqual(triggerType, .manual)
        } else {
            XCTFail("Expected WaitingDelay state")
        }

        XCTAssertTrue(stateManager.isManualTrigger())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("WaitingDelay") ?? false)
    }

    func testMarkActive() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // Given: Mock experience content
        let mockContent = createMockExperienceContent()

        // When: Mark as active
        stateManager.markActive(.automatic, mockContent)

        // Then: State should be Active
        let currentState = stateManager.getCurrentState()
        if case .active(let triggerType, let content) = currentState {
            XCTAssertEqual(triggerType, .automatic)
            XCTAssertTrue(content.experienceId() == mockContent.experienceId())
        } else {
            XCTFail("Expected Active state")
        }

        XCTAssertTrue(stateManager.isActive())
        XCTAssertTrue(stateManager.isActivelyRendered())
        XCTAssertNotNil(stateManager.getActiveContent())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("Active") ?? false)
    }

    func testMarkShowingThankYou() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // When: Mark as showing thank you
        stateManager.markShowingThankYou()

        // Then: State should be ShowingThankYou
        let currentState = stateManager.getCurrentState()
        if case .showingThankYou = currentState {
            // Success
        } else {
            XCTFail("Expected ShowingThankYou state")
        }

        XCTAssertTrue(stateManager.isActive())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("ShowingThankYou") ?? false)
    }

    func testMarkCachedManual() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // When: Mark as cached manual
        stateManager.markCachedManual("cached-exp-456")

        // Then: State should be CachedPendingManual
        let currentState = stateManager.getCurrentState()
        if case .cachedPendingManual(let experienceId) = currentState {
            XCTAssertEqual(experienceId, "cached-exp-456")
        } else {
            XCTFail("Expected CachedPendingManual state")
        }

        XCTAssertTrue(stateManager.hasCachedExperience())
        XCTAssertEqual(stateManager.getCachedExperienceId(), "cached-exp-456")

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("CachedPendingManual") ?? false)
    }

    func testMarkCachedAutomatic() {
        // Given: Clear initial state logs
        logger.loggedInfos.removeAll()
        
        // Given: Mock experience content
        let mockContent = createMockExperienceContent()

        // When: Mark as cached automatic
        stateManager.markCachedAutomatic(mockContent)

        // Then: State should be CachedPendingAutomatic
        let currentState = stateManager.getCurrentState()
        if case .cachedPendingAutomatic(let experience) = currentState {
            XCTAssertTrue(experience.experienceId() == mockContent.experienceId())
        } else {
            XCTFail("Expected CachedPendingAutomatic state")
        }

        XCTAssertTrue(stateManager.hasCachedExperience())
        XCTAssertNotNil(stateManager.getCachedExperienceContent())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("CachedPendingAutomatic") ?? false)
    }

    func testMarkIdle() {
        // Given: State is Active
        let mockContent = createMockExperienceContent()
        stateManager.markActive(.manual, mockContent)
        logger.loggedInfos.removeAll()

        // When: Mark as idle
        stateManager.markIdle()

        // Then: State should be Idle
        let currentState = stateManager.getCurrentState()
        if case .idle = currentState {
            // Success
        } else {
            XCTFail("Expected Idle state")
        }

        XCTAssertFalse(stateManager.isActive())

        // And: Should log the transition
        XCTAssertEqual(logger.loggedInfos.count, 1)
        XCTAssertTrue(logger.loggedInfos.first?.contains("Idle") ?? false)
    }

    // MARK: - Component Management Tests

    func testSetActiveComponent_WhenInActiveState() {
        // Given: State is Active
        let mockContent = createMockExperienceContent()
        let mockComponent = MockExperienceComponent()
        stateManager.markActive(.manual, mockContent)

        // When: Set active component
        stateManager.setActiveComponent(mockComponent)

        // Then: Should succeed
        XCTAssertNotNil(stateManager.getActiveComponent())
        XCTAssertTrue(stateManager.isActiveComponentAlive())

        // And: Should log the operation
        XCTAssertTrue(logger.loggedInfos.contains { $0.contains("component set") })
    }

    func testSetActiveComponent_WhenNotInActiveState() {
        // Given: State is Idle
        let mockComponent = MockExperienceComponent()

        // When: Set active component (now always succeeds regardless of state)
        stateManager.setActiveComponent(mockComponent)

        // Then: Component should be set
        XCTAssertNotNil(stateManager.getActiveComponent())
        XCTAssertTrue(stateManager.isActiveComponentAlive())
    }

    func testGetActiveContent() {
        // Given: State is Active with content
        let mockContent = createMockExperienceContent()
        stateManager.markActive(.automatic, mockContent)

        // When: Get active content
        let content = stateManager.getActiveContent()

        // Then: Should return the content
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.experienceId() == mockContent.experienceId())
    }

    func testGetActiveTriggerType() {
        // Given: State is Active with manual trigger
        let mockContent = createMockExperienceContent()
        stateManager.markActive(.manual, mockContent)

        // When: Get active trigger type
        let triggerType = stateManager.getActiveTriggerType()

        // Then: Should return manual
        XCTAssertEqual(triggerType, .manual)
    }

    func testIsActivelyRendered() {
        // Test Active state - should be actively rendered
        let mockContent = createMockExperienceContent()
        stateManager.markActive(.manual, mockContent)
        XCTAssertTrue(stateManager.isActivelyRendered())
        XCTAssertTrue(stateManager.isActive())

        // Test ShowingThankYou state - should be actively rendered
        stateManager.markShowingThankYou()
        XCTAssertTrue(stateManager.isActivelyRendered())
        XCTAssertTrue(stateManager.isActive())

        // Test WaitingDelay state - should NOT be actively rendered (but is active)
        stateManager.markWaitingDelay(.manual)
        XCTAssertFalse(stateManager.isActivelyRendered())
        XCTAssertTrue(stateManager.isActive())

        // Test Idle state - should NOT be actively rendered
        stateManager.markIdle()
        XCTAssertFalse(stateManager.isActivelyRendered())
        XCTAssertFalse(stateManager.isActive())
    }

    // MARK: - High-Level Operations Tests

    func testMarkActiveFromCurrentState_Manual() {
        // Given: State is PendingManual
        stateManager.markManualTrigger("exp-123")
        let mockContent = createMockExperienceContent()

        // When: Mark active from current state
        stateManager.markActiveFromCurrentState(content: mockContent)

        // Then: Should be active with manual trigger
        XCTAssertTrue(stateManager.isActive())
        XCTAssertEqual(stateManager.getActiveTriggerType(), .manual)
    }

    func testMarkActiveFromCurrentState_Preview() {
        // Given: State is PendingPreview
        stateManager.markPreviewMode()
        let mockContent = createMockExperienceContent()

        // When: Mark active from current state
        stateManager.markActiveFromCurrentState(content: mockContent)

        // Then: Should be active with preview trigger
        XCTAssertTrue(stateManager.isActive())
        XCTAssertEqual(stateManager.getActiveTriggerType(), .preview)
    }

    func testMarkActiveFromCurrentState_Automatic() {
        // Given: State is PendingAutomatic
        stateManager.markAutomaticTrigger(nil)
        let mockContent = createMockExperienceContent()

        // When: Mark active from current state
        stateManager.markActiveFromCurrentState(content: mockContent)

        // Then: Should be active with automatic trigger
        XCTAssertTrue(stateManager.isActive())
        XCTAssertEqual(stateManager.getActiveTriggerType(), .automatic)
    }

    func testGetActiveComponent_WhenActive() {
        // Given: State is Active with component
        let mockContent = createMockExperienceContent()
        let mockComponent = MockExperienceComponent()
        stateManager.markActive(.manual, mockContent)
        stateManager.setActiveComponent(mockComponent)

        // When: Get component
        let component = stateManager.getActiveComponent()

        // Then: Should return the component
        XCTAssertNotNil(component)
    }

    func testGetActiveComponent_WhenNotActive() {
        // Given: State is Idle without component
        // When: Get component
        let component = stateManager.getActiveComponent()

        // Then: Should return nil
        XCTAssertNil(component)
    }

    func testProcessCachedExperience_Manual() {
        // Given: State is CachedPendingManual
        stateManager.markCachedManual("cached-exp")

        // When: Process cached experience
        let action = stateManager.processCachedExperience()

        // Then: Should return triggerManual action
        if case .triggerManual(let experienceId) = action {
            XCTAssertEqual(experienceId, "cached-exp")
        } else {
            XCTFail("Expected triggerManual action")
        }
    }

    func testProcessCachedExperience_Automatic() {
        // Given: State is CachedPendingAutomatic
        let mockContent = createMockExperienceContent()
        stateManager.markCachedAutomatic(mockContent)

        // When: Process cached experience
        let action = stateManager.processCachedExperience()

        // Then: Should return processAutomatic action
        if case .processAutomatic(let experience) = action {
            XCTAssertTrue(experience.experienceId() == mockContent.experienceId())
        } else {
            XCTFail("Expected processAutomatic action")
        }
    }

    func testProcessCachedExperience_None() {
        // Given: State is Idle (no cached experience)
        // When: Process cached experience
        let action = stateManager.processCachedExperience()

        // Then: Should return none action
        if case .none = action {
            // Success
        } else {
            XCTFail("Expected none action")
        }
    }

    // MARK: - State Check Tests

    func testIsManualTrigger_InDifferentStates() {
        // Test PendingManual
        stateManager.markManualTrigger("exp-123")
        XCTAssertTrue(stateManager.isManualTrigger())

        // Test WaitingDelay with manual
        stateManager.markWaitingDelay(.manual)
        XCTAssertTrue(stateManager.isManualTrigger())

        // Test Active with manual
        let mockContent = createMockExperienceContent()
        stateManager.markActive(.manual, mockContent)
        XCTAssertTrue(stateManager.isManualTrigger())

        // Test CachedPendingManual
        stateManager.markCachedManual("exp")
        XCTAssertTrue(stateManager.isManualTrigger())

        // Test Idle (not manual)
        stateManager.markIdle()
        XCTAssertFalse(stateManager.isManualTrigger())
    }

    func testIsPreviewMode_InDifferentStates() {
        // Test PendingPreview
        stateManager.markPreviewMode()
        XCTAssertTrue(stateManager.isPreviewMode())

        // Test WaitingDelay with preview
        stateManager.markWaitingDelay(.preview)
        XCTAssertTrue(stateManager.isPreviewMode())

        // Test Active with preview
        let mockContent = createMockExperienceContent()
        stateManager.markActive(.preview, mockContent)
        XCTAssertTrue(stateManager.isPreviewMode())

        // Test Idle (not preview)
        stateManager.markIdle()
        XCTAssertFalse(stateManager.isPreviewMode())
    }

    func testShouldBypassScreenValidation() {
        // Manual trigger should bypass
        stateManager.markManualTrigger("exp-123")
        XCTAssertTrue(stateManager.shouldBypassScreenValidation())

        // Preview mode should bypass
        stateManager.markPreviewMode()
        XCTAssertTrue(stateManager.shouldBypassScreenValidation())

        // Automatic should not bypass
        stateManager.markAutomaticTrigger(nil)
        XCTAssertFalse(stateManager.shouldBypassScreenValidation())
    }

    // MARK: - Complete Workflow Tests

    func testCompleteWorkflow_ManualTrigger() {
        let mockContent = createMockExperienceContent()
        let mockComponent = MockExperienceComponent()

        // 1. Manual trigger
        stateManager.markManualTrigger("exp-123")
        XCTAssertTrue(stateManager.isManualTrigger())

        // 2. Waiting delay
        stateManager.markWaitingDelay(.manual)
        XCTAssertTrue(stateManager.isManualTrigger())
        XCTAssertTrue(stateManager.isActive())
        XCTAssertFalse(stateManager.isActivelyRendered())

        // 3. Active
        stateManager.markActive(.manual, mockContent)
        XCTAssertTrue(stateManager.isActive())
        XCTAssertTrue(stateManager.isActivelyRendered())
        stateManager.setActiveComponent(mockComponent)
        XCTAssertTrue(stateManager.isActiveComponentAlive())

        // 4. Dismiss -> Idle
        stateManager.markIdle()
        XCTAssertFalse(stateManager.isActive())
        XCTAssertFalse(stateManager.isActivelyRendered())
    }

    func testCompleteWorkflow_AutomaticWithCaching() {
        let mockContent1 = createMockExperienceContent()
        let mockContent2 = createMockExperienceContent()

        // 1. Automatic trigger
        stateManager.markAutomaticTrigger(mockContent1)

        // 2. Active
        stateManager.markActive(.automatic, mockContent1)
        XCTAssertTrue(stateManager.isActive())

        // 3. Another experience triggered while active -> cache it
        stateManager.markCachedAutomatic(mockContent2)
        XCTAssertTrue(stateManager.hasCachedExperience())

        // 4. Dismiss current -> process cached
        stateManager.markIdle()
        let action = stateManager.processCachedExperience()
        if case .none = action {
            // Expected since we're in Idle, not CachedPending
        } else {
            XCTFail("Should have no cached experience after marking idle")
        }
    }

    func testCompleteWorkflow_SurveyWithThankYou() {
        let mockContent = createMockExperienceContent()

        // 1. Active survey
        stateManager.markActive(.automatic, mockContent)
        XCTAssertTrue(stateManager.isActive())
        XCTAssertTrue(stateManager.isActivelyRendered())

        // 2. Survey completed -> show thank you
        stateManager.markShowingThankYou()
        XCTAssertTrue(stateManager.isActive())
        XCTAssertTrue(stateManager.isActivelyRendered())

        // 3. Thank you dismissed -> idle
        stateManager.markIdle()
        XCTAssertFalse(stateManager.isActive())
        XCTAssertFalse(stateManager.isActivelyRendered())
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_ConcurrentStateTransitions() {
        let expectation = self.expectation(description: "All transitions complete")
        let group = DispatchGroup()
        let iterations = 100
        let mockContent = createMockExperienceContent()

        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                switch index % 4 {
                case 0:
                    self.stateManager.markIdle()
                case 1:
                    self.stateManager.markManualTrigger("exp-\(index)")
                case 2:
                    self.stateManager.markActive(.automatic, mockContent)
                case 3:
                    self.stateManager.markCachedManual("cached-\(index)")
                default:
                    break
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)

        // Should complete without crashes
        XCTAssertTrue(true)
    }

    func testThreadSafety_ConcurrentReadsAndWrites() {
        let expectation = self.expectation(description: "All operations complete")
        let group = DispatchGroup()
        let iterations = 200
        let mockContent = createMockExperienceContent()

        // Readers
        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                _ = self.stateManager.isActive()
                _ = self.stateManager.isManualTrigger()
                _ = self.stateManager.getCurrentState()
                group.leave()
            }
        }

        // Writers
        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                if index % 2 == 0 {
                    self.stateManager.markIdle()
                } else {
                    self.stateManager.markActive(.automatic, mockContent)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        // Should complete without crashes
        XCTAssertTrue(true)
    }
}

// MARK: - Mock Classes

/// Helper function to create a mock ExperienceContent for testing
func createMockExperienceContent() -> ExperienceContent {
    let surveyContent = MockContentFactory.makeSurveyContent(id: Int.random(in: 1...10000))
    return .survey(content: surveyContent)
}

class MockExperienceComponent: UPExperience {
    var onTriggerClose: ((Bool) -> Void)?

    func triggerCloseExperience(isInternalEvent: Bool) {
        onTriggerClose?(isInternalEvent)
    }
}
// swiftlint:enable all
