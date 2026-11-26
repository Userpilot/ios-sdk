//
//  ExperienceViewModelOwnershipTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies that shared view-model reporting stays bound to its original renderer and weak owner.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {
    func testAllViewModelsKeepOriginalRendererAfterReplacement() throws {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        let original = try XCTUnwrap(publisher.activeRendererID)
        userpilot.container.register(ElementTargeting.self, value: MockTooltipTargeting(owner: userpilot))
        publishedEvents.removeAll()
        let models: [BaseExperienceViewModel] = [
            ExperienceViewModel(container: userpilot.container),
            SurveyViewModel(container: userpilot.container),
            NPSViewModel(container: userpilot.container),
            TooltipViewModel(container: userpilot.container)
        ]
        XCTAssertTrue(publishedEvents.isEmpty, "Construction must not report a seen event")
        XCTAssertTrue(models.allSatisfy { $0.rendererID == original })
        models.forEach { $0.publishEvent(FlowExperienceActionEvent.seen(flowId: 77)) }
        publisher.mockWaitForQueue()
        XCTAssertEqual(publishedEvents.count, models.count)

        publisher.experienceDidFinishDismissing(rendererID: original)
        settle()
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        let replacement = try XCTUnwrap(publisher.activeRendererID)
        XCTAssertNotEqual(original, replacement)
        publishedEvents.removeAll()
        models.forEach {
            $0.publishEvent(FlowExperienceActionEvent.seen(flowId: 77))
            $0.setCompletionDeepLink("https://example.com/old-renderer")
            $0.onExperienceDismissalCompleted()
        }
        settle()
        XCTAssertTrue(publishedEvents.isEmpty)
        XCTAssertEqual(publisher.activeRendererID, replacement)
        XCTAssertEqual(reloadCount, 0)
    }

    func testSharedViewModelDoesNotRetainSDKOwner() {
        weak var owner: MockUserpilot?
        let model = autoreleasepool { () -> NPSViewModel in
            let instance = MockUserpilot.make(
                config: Userpilot.Config(token: UUID().uuidString).defaultInstance(false)
            )
            owner = instance
            return NPSViewModel(container: instance.container)
        }
        XCTAssertNil(owner)
        XCTAssertNil(model.userpilot)
        withExtendedLifetime(model) {}
    }
}
