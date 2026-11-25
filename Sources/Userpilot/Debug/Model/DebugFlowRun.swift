//
//  DebugFlowRun.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Groups the steps observed during one Flow run in the debugger.
//

import Foundation

/// One Flow walk as the debugger sees it. Its identity stays with the publisher operation across renderer
/// changes. Only the operation holds the full content. Debug history keeps just step identities and outcomes.
internal struct DebugFlowContext {
    let operationID = UUID()
    let flow: FlowContent
    let isPreview: Bool
    /// The SDK generation the walk ran in; a paused run resumes only within the same one.
    let generation: UUID
}

/// One Flow run's history in the debugger's Flow tab: its state and each step it has seen.
internal struct DebugFlowRun {
    enum State: String {
        case pending = "Pending", started = "Started", inProgress = "In progress", paused = "Paused"
        case completed = "Completed", dismissed = "Dismissed"

        var isTerminal: Bool { self == .completed || self == .dismissed }
    }

    /// The run's number in the section title, counted from 1 until the store resets.
    let number: Int
    let flowID: Int
    let isPreview: Bool
    let generation: UUID
    /// The latest operation that showed this run; a resumed run takes the new one.
    var operationID: UUID
    /// The Flow's `steps_count`, once a payload carried it.
    var total: Int?
    var state = State.pending
    var steps: [Int: DebugFlowStep] = [:]

    /// Moves the run to `context`'s operation and adds its steps not seen before, as pending.
    mutating func include(_ context: DebugFlowContext) {
        operationID = context.operationID
        for step in context.flow.steps where steps[step.id] == nil {
            steps[step.id] = DebugFlowStep(id: step.id, position: step.position, type: step.stepType ?? .modal)
        }
        total = context.flow.stepsCount ?? total
    }

    /// Applies an outcome's host callbacks and target errors; `screen` is where its steps were shown.
    mutating func record(_ outcome: FlowStepOutcome, screen: String?) {
        state = .inProgress
        for callback in outcome.callbacks {
            switch callback {
            case .experienceState(.started): state = .started
            case .experienceState(.completed): state = .completed
            case .experienceState(.dismissed): state = .dismissed
            case .stepState(let status, let id, _, _): steps[id]?.record(status, screen: screen)
            default: break
            }
        }
        for case let error as FlowContentErrorEvent in outcome.events {
            steps[error.stepId]?.record(error)
        }
        // Recording may start mid-run. The renderer knows which steps ended, but not their earlier outcomes.
        for id in outcome.run.endedStepIds where steps[id]?.state == .pending { steps[id]?.state = .notObserved }
    }

    /// The run and any step still showing are paused.
    mutating func pause() {
        state = .paused
        for id in steps.keys where steps[id]?.state == .shown { steps[id]?.state = .paused }
    }

    /// The run's section in the Flow tab, its steps sorted by `position`.
    var section: DebugSection {
        let title = "Flow \(flowID) · Run \(number)\(isPreview ? " · Preview" : "") · \(state.rawValue)"
        let sorted = steps.values.sorted { ($0.position ?? 0, $0.id) < ($1.position ?? 0, $1.id) }
        return DebugSection(title: title, rows: sorted.map { $0.row(total: total, terminal: state.isTerminal) })
    }
}

/// One step's last observed state, the screen it was shown on and its target errors.
internal struct DebugFlowStep {
    enum State: String {
        case pending = "Pending", shown = "Shown", paused = "Paused", completed = "Completed"
        case dismissed = "Dismissed", failed = "Failed"
        case notObserved = "Not observed"
    }

    struct TargetError: Equatable {
        let issue: String
        let screen: String?
    }

    let id: Int
    let position: Int?
    let type: FlowStepType
    var state = State.pending
    var shownOn: String?
    var errors: [TargetError] = []

    /// Applies the step's host callback state; any other state leaves the step as it was.
    mutating func record(_ status: UserpilotExperienceState, screen: String?) {
        switch status {
        case .started:
            state = .shown
            shownOn = screen
        case .completed: state = .completed
        case .dismissed: state = .dismissed
        default: break
        }
    }

    /// Marks the step failed, keeping each distinct issue and screen once.
    mutating func record(_ error: FlowContentErrorEvent) {
        state = .failed
        let detail = TargetError(issue: error.issue, screen: error.screen)
        if !errors.contains(detail) { errors.append(detail) }
    }

    /// The step's row; a step still pending when its run ended shows as not observed.
    func row(total: Int?, terminal: Bool) -> DebugProperty {
        let position = position.map(String.init) ?? "?"
        let count = total.map { " of \($0)" } ?? ""
        let title = "Step \(position)\(count) · \(type.rawValue.capitalized) · #\(id)"
        var lines = [terminal && state == .pending ? State.notObserved.rawValue : state.rawValue]
        if let shownOn { lines.append("Shown on \(shownOn)") }
        for error in errors { lines.append("Error: " + error.issue + (error.screen.map { " on \($0)" } ?? "")) }
        return DebugProperty(key: title, value: lines.joined(separator: "\n"))
    }
}
