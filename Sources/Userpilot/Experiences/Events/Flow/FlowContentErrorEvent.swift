//
//  FlowContentErrorEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Reports that a Flow tooltip step's target can't be used (`mobile_content_error`).
//
//  Fire and forget, and offline-eligible: the server records the step error and completes a skipped final step.
//  An explicit `end_flow` fallback also sends the Flow completion. It is not a close event, so it neither
//  records a close nor requests the post-close screen reload; the Flow's fallback decides
//  what the SDK shows next.
//
//  Carries only the failure's shape. `issue` is drawn from the fixed resolution vocabulary
//  (`not_found`, `not_visible`, `not_in_view`, `overlapped`, `ambiguous`), never selector
//  values or host-app text.
//

/// `mobile_content_error` for one Flow step, built by `FlowStepEvents.failed`.
internal struct FlowContentErrorEvent: ExperienceEvent {
    let flowId: Int
    let stepId: Int

    /// One of `issues`: the failure's shape, never selector values or host-app text.
    let issue: String

    /// The screen title the step was shown on; omitted from the payload when unknown.
    let screen: String?

    /// The error ended the run (`end_flow`, or the Flow's last step), so its `error_steps` are dropped.
    /// It is never part of the payload.
    var endsRun = false

    var name: SDKEventsName { .flowContentError }

    var experience: (type: ExperienceType, id: Int)? { (.flow, flowId) }

    var eventPayload: [String: Any] {
        var payload: [String: Any] = ["mobile_content_id": flowId, "step_id": stepId, "issue": issue]
        payload["screen"] = screen
        return payload
    }

    /// The resolver folds an off-screen target into `not_found`, so `not_in_view` is accepted, never produced.
    private static let issues: Set<String> = ["not_found", "not_visible", "not_in_view", "overlapped", "ambiguous"]

    /// The issue a tooltip target alert `reason` reports, or nil for a failure that is not the target's.
    static func issue(for reason: String) -> String? {
        issues.contains(reason) ? reason : nil
    }
}
