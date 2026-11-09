//
//  ExperienceRenderState.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Adapts concrete ViewModels to SwiftUI without moving experience or delivery ownership.
//

import Combine
import SwiftUI
import UIKit

/// Main-confined presentation state. Body evaluation never starts or completes an experience.
internal final class ExperienceRenderState: ObservableObject {
    enum Content {
        case flow(ExperienceViewModel)
        case survey(SurveyViewModel)
        case nps(NPSViewModel)
        case thankYou(SurveyContent, SurveyTheme)
    }

    let content: Content
    /// `Config.enableTextScaling`, fixed for this presentation.
    let textScaling: Bool
    // Bumped on every change so views observing the state redraw.
    @Published private(set) var revision = 0
    /// Whether the survey's visible questions are valid; published only when that changes.
    @Published private(set) var canSubmit = false
    private(set) var isReady = false
    private(set) var hasStarted = false
    private(set) var hasAppeared = false
    private(set) var isClosing = false
    private var answerModels: [Int: SurveyAnswerModel] = [:]
    /// Per image and decode size; kept here so iOS 13 `@ObservedObject` recreation can't reload or flicker.
    private var imageModels: [String: UPImageModel] = [:]
    var npsStep = 0
    var npsScore = 0
    var npsFeedback = "" {
        didSet {
            // The NPS feedback field is capped at 500 characters.
            if npsFeedback.count > 500 { npsFeedback = String(npsFeedback.prefix(500)) }
            refresh()
        }
    }
    var dismiss: ((@escaping () -> Void) -> Void)?
    var didChange: (() -> Void)?
    var actionButtonClicked: ((String?) -> Void)?
    var onDismissCompleted: (() -> Void)?

    init(_ content: Content, textScaling: Bool = false) {
        self.content = content
        self.textScaling = textScaling
    }

    /// Bind once to the existing business owner, before its onStart callback.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        switch content {
        case .flow(let model):
            model.bindData = { [weak self] in self?.didBind($0) }
            model.onStart()
        case .survey(let model):
            model.bindData = { [weak self] in self?.didBind($0) }
            model.bindNextSurveyStep = { [weak self] in self?.refresh() }
            model.closeSurvey = { [weak self] in self?.close() }
            model.onStart()
        case .nps(let model):
            model.bindData = { [weak self] in self?.didBind($0) }
            model.onStart()
        // A thank-you screen needs no ViewModel; it's ready when the survey ends with a completion module.
        case .thankYou(let survey, _): didBind(survey.modules.last?.type == .completed)
        }
    }

    /// Native appearance is the source of seen events, not SwiftUI onAppear/recomputation.
    func appeared() {
        guard isReady, !hasAppeared, !isClosing else { return }
        hasAppeared = true
        switch content {
        case .flow(let model): model.onExperienceSeen()
        case .survey(let model): model.onExperienceSeen()
        case .nps(let model): model.onExperienceSeen()
        case .thankYou: break
        }
    }

    private func didBind(_ ready: Bool) {
        isReady = ready
        refresh()
    }

    func refresh() {
        updateCanSubmit()
        revision += 1
        didChange?()
    }

    func answer(for step: SurveyStep) -> SurveyAnswerState { answerModels[step.id]?.value ?? SurveyAnswerState() }

    func answerModel(for step: SurveyStep) -> SurveyAnswerModel {
        if let model = answerModels[step.id] { return model }
        let model = SurveyAnswerModel()
        answerModels[step.id] = model
        return model
    }

    func imageModel(url: String, blurHash: String?, size: CGSize, loader: ImageLoading) -> UPImageModel {
        // Payload-derived sizes can be absurd; describe them rather than converting to Int, which traps.
        let key = "\(url)|\(size.width)x\(size.height)"
        if let model = imageModels[key] { return model }
        let model = UPImageModel(url: url, blurHash: blurHash, size: size, loader: loader)
        imageModels[key] = model
        return model
    }

    /// Notifies only this question's model (and `canSubmit` when validity flips); the host re-measures,
    /// because a choice can reveal the "Other" field.
    func updateAnswer(for step: SurveyStep, _ update: (inout SurveyAnswerState) -> Void) {
        updateText(for: step, update)
        didChange?()
    }

    /// For typing: text inputs have fixed heights, so a keystroke never changes the card's size and skips
    /// re-measuring the whole survey.
    func updateText(for step: SurveyStep, _ update: (inout SurveyAnswerState) -> Void) {
        guard !isClosing else { return }
        let model = answerModel(for: step)
        var value = model.value
        update(&value)
        model.value = value
        updateCanSubmit()
    }

    /// For local layout changes, such as an inline picker opening: the host re-measures without redrawing.
    func remeasure() {
        didChange?()
    }

    private func updateCanSubmit() {
        guard case .survey(let model) = content, let survey = model.surveyContent else { return }
        // A list survey checks every question; a step survey only the one on screen.
        let questions = survey.type == .list
            ? survey.modules : survey.modules[safe: model.currentStep].map { [$0] } ?? []
        let valid = questions.allSatisfy { answer(for: $0).isValid(for: $0) }
        if valid != canSubmit { canSubmit = valid }
    }

    func selectFlowStep(_ index: Int) {
        guard !isClosing, case .flow(let model) = content,
            model.flowContent?.steps.indices.contains(index) == true, index != model.currentStep
        else { return }
        model.onStepChanged(index)
        refresh()
    }

    func flowAction() {
        guard !isClosing, case .flow(let model) = content,
            let flow = model.flowContent,
            flow.steps[safe: model.currentStep]?.buttonAction != nil
        else { return }
        // A carousel button moves to the next page; on the last page it completes the flow.
        if flow.type == .carousel, model.currentStep < flow.steps.count - 1 {
            selectFlowStep(model.currentStep + 1)
        } else if flow.type == .slideout {
            // A slideout reports completion once the card has gone, then opens its deep link.
            close(beforeCompletion: { [weak model] in model?.onExperienceCompleted() },
                  afterDismiss: { [weak model] in model?.onDeepLinkTriggered() })
        } else {
            model.onExperienceCompleted()
            close { [weak model] in model?.onDeepLinkTriggered() }
        }
    }

    func submitSurvey() {
        guard !isClosing, case .survey(let model) = content, let survey = model.surveyContent else { return }
        if survey.type == .list {
            let questions = survey.modules.filter { $0.type != .completed }
            guard questions.allSatisfy({ answer(for: $0).isValid(for: $0) }) else { return }
            model.onSurveyListSubmitted(answersPayload: questions.compactMap { answer(for: $0).payload(for: $0) })
            close(continueSurvey: true)
        } else if let step = survey.modules[safe: model.currentStep] {
            let value = answer(for: step)
            guard value.isValid(for: step) else { return }
            model.moveToNextSurveyStep(value.answer(for: step), value.payload(for: step))
        }
    }

    func userClose() {
        guard !isClosing else { return }
        switch content {
        case .flow(let model):
            if model.flowContent?.type == .slideout {
                close(beforeCompletion: { [weak model] in model?.onDismissStep() })
                return
            }
            model.onDismissStep()
        case .survey(let model): model.onSurveyDismissed()
        // Closing on the score stage is a dismissal; on the feedback stage the chosen score is still sent.
        case .nps(let model):
            if npsStep == 0 { model.onNPSDismissed() }
            if npsStep == 1 { submitNPS(showCompletion: false, includeFeedback: false) }
        case .thankYou: actionButtonClicked?(nil)
        }
        close()
    }

    /// Programmatic cancellation preserves legacy manual-close analytics behavior for fullscreen flows/lists.
    func cancel(manualClose: Bool) {
        guard !isClosing else { return }
        if manualClose {
            switch content {
            case .flow(let model) where model.flowContent?.type == .carousel: model.onDismissStep()
            case .survey(let model) where model.surveyContent?.type == .list: model.onSurveyDismissed()
            default: break
            }
        }
        close()
    }

    func finishThankYou() {
        guard !isClosing, case .thankYou(let survey, _) = content else { return }
        actionButtonClicked?(survey.thankYouDeepLink)
        close()
    }

    /// Analytics and continuation are settled only from the native dismissal completion.
    func close(continueSurvey: Bool = false, beforeCompletion: (() -> Void)? = nil,
               afterDismiss: (() -> Void)? = nil) {
        guard !isClosing else { return }
        isClosing = true
        // Redraw once so every control is disabled during the exit animation.
        refresh()
        dismiss? { [weak self] in
            guard let self else { return }
            beforeCompletion?()
            switch self.content {
            case .flow(let model): model.onExperienceDismissalCompleted()
            case .survey(let model):
                // A submitted survey may hand over to its thank-you screen instead of finishing here.
                if !continueSurvey || !model.showThankYouMessage() { model.onExperienceDismissalCompleted() }
            case .nps(let model): model.onExperienceDismissalCompleted()
            case .thankYou: self.onDismissCompleted?()
            }
            afterDismiss?()
        }
    }
}
