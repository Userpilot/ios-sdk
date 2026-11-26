//
//  DebugEventStore.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns debugger recording and bounded per-channel history for one SDK instance.
//

import Foundation

/// Recording, reset and buffer updates share one lock. UI observers receive invalidations, not stale snapshots.
internal protocol DebugEventStoring: AnyObject {
    func start()
    func stop()
    func reset()
    func record(_ event: Event)
    func record(_ event: SDKEvent)
    /// A preview's event, which is never sent; its row leaves out survey and NPS answers.
    func recordPreview(_ event: SDKEvent)
    func recordFlow(_ context: DebugFlowContext, outcome: FlowStepOutcome?, screen: String?)
    func pauseFlow(operationID: UUID)
    var flowRuns: [DebugFlowRun] { get }
    func events(for channel: DebugEventChannel) -> [DebugEvent]
    func observe(_ channel: DebugEventChannel, handler: @escaping () -> Void) -> UUID
    func removeObserver(_ id: UUID)
}

internal final class DebugEventStore: DebugEventStoring {

    static let maxEvents = 50

    private let lock = NSLock()
    private let mapper = DebugEventMapper()
    private var isStarted = false
    private var buffers: [DebugEventChannel: [DebugEvent]] = [:]
    private var runs: [DebugFlowRun] = []
    private var lastRunNumber = 0
    private var observers: [UUID: (channel: DebugEventChannel, handler: () -> Void)] = [:]

    func start() {
        lock.withLock { isStarted = true }
    }

    func stop() {
        lock.withLock { isStarted = false }
    }

    /// Clearing is synchronous: there is no pending event bus that can repopulate history after logout.
    func reset() {
        let handlers = lock.withLock {
            buffers.removeAll()
            runs.removeAll()
            lastRunNumber = 0
            return observers.values.map(\.handler)
        }
        handlers.forEach { $0() }
    }

    func record(_ event: Event) {
        record { mapper.fromAnalytics(event) }
    }

    func record(_ event: SDKEvent) {
        record { mapper.fromInternal(event) }
    }

    func recordPreview(_ event: SDKEvent) {
        record { mapper.fromPreview(event) }
    }

    /// Flow runs, newest first, at most `maxEvents`.
    var flowRuns: [DebugFlowRun] { lock.withLock { runs } }

    /// A Flow walk started (`outcome` nil) or reported a step outcome. A payload without steps, or an
    /// outcome that sent nothing, records nothing.
    func recordFlow(_ context: DebugFlowContext, outcome: FlowStepOutcome?, screen: String?) {
        update {
            guard !context.flow.steps.isEmpty, outcome?.events.isEmpty != true else { return nil }
            let index = flowIndex(for: context)
            if let outcome { runs[index].record(outcome, screen: screen) }
            return .flow
        }
    }

    /// The operation ended before its run did; a run that already ended stays as it was.
    func pauseFlow(operationID: UUID) {
        update {
            guard let index = runs.firstIndex(where: { $0.operationID == operationID }),
                  !runs[index].state.isTerminal else { return nil }
            runs[index].pause()
            return .flow
        }
    }

    /// Later positions can resume the latest paused run. A new first step starts a separate history entry.
    private func flowIndex(for context: DebugFlowContext) -> Int {
        if let index = runs.firstIndex(where: { $0.operationID == context.operationID }) { return index }
        let flow = context.flow
        if !context.isPreview, flow.steps.allSatisfy({ ($0.position ?? 1) > 1 }),
           let index = runs.firstIndex(where: { $0.flowID == flow.id && !$0.isPreview }),
           runs[index].generation == context.generation,
           runs[index].state == .paused {
            var resumed = runs.remove(at: index)
            resumed.include(context)
            resumed.state = .inProgress
            runs.insert(resumed, at: 0)
        } else {
            lastRunNumber += 1
            var run = DebugFlowRun(number: lastRunNumber, flowID: flow.id, isPreview: context.isPreview,
                                   generation: context.generation, operationID: context.operationID)
            run.include(context)
            runs.insert(run, at: 0)
            if runs.count > Self.maxEvents { runs.removeLast() }
        }
        return 0
    }

    func events(for channel: DebugEventChannel) -> [DebugEvent] {
        lock.withLock { buffers[channel] ?? [] }
    }

    /// Callers read the latest events on their UI queue, so a delayed update cannot undo a reset.
    func observe(_ channel: DebugEventChannel, handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        lock.withLock { observers[id] = (channel, handler) }
        handler()
        return id
    }

    func removeObserver(_ id: UUID) {
        lock.withLock { observers[id] = nil }
    }

    /// Mapping is deferred until recording is enabled, and IDs follow the same order as buffer admission.
    private func record(_ makeEvent: () -> DebugEvent) {
        update {
            let event = makeEvent()
            var buffer = buffers[event.channel] ?? []
            buffer.insert(event, at: 0)
            if buffer.count > Self.maxEvents { buffer.removeLast() }
            buffers[event.channel] = buffer
            return event.channel
        }
    }

    private func update(_ change: () -> DebugEventChannel?) {
        let handlers: [() -> Void] = lock.withLock {
            guard isStarted, let channel = change() else { return [] }
            return observers.values.filter { $0.channel == channel }.map(\.handler)
        }
        // UI code may reenter the store; no external callback runs under the state lock.
        handlers.forEach { $0() }
    }
}
