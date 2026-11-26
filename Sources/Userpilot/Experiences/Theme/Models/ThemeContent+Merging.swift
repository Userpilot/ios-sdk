//
//  ThemeContent+Merging.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pure, field-by-field theme fallback shared by carousel, slide-out, survey and Flow step preparation.
//

extension Optional where Wrapped == ExperienceTheme {
    /// A missing layer contributes no fields. Explicit false, zero and empty strings remain overrides.
    func merging(globalTheme: ExperienceTheme?, stepTheme: ExperienceTheme?) -> ExperienceTheme {
        ExperienceTheme(
            button: (self?.button).merging(global: globalTheme?.button, step: stepTheme?.button),
            colors: (self?.colors).merging(global: globalTheme?.colors, step: stepTheme?.colors),
            dismissContent: (self?.dismissContent).merging(
                global: globalTheme?.dismissContent,
                step: stepTheme?.dismissContent
            ),
            general: (self?.general).merging(global: globalTheme?.general, step: stepTheme?.general),
            progress: (self?.progress).merging(global: globalTheme?.progress, step: stepTheme?.progress),
            backdrop: (self?.backdrop).merging(global: globalTheme?.backdrop, step: stepTheme?.backdrop)
        )
    }
}

/// One Flow step's theme: step → the Flow's custom theme → `baseTheme`'s `flow` section, else each
/// branch's own section → rendering defaults. The presenter picks its branch by step type, so each
/// branch falls back to its own section. Explicit step placement and backdrop take priority.
func mergeFlowStepThemes(
    baseTheme: ThemeData?,
    contentTheme: ExperienceTheme?,
    stepTheme: ExperienceTheme?,
    step: Step
) -> ThemeData {
    let flow = baseTheme?.flow
    let stepBackdrop = step.settings?.backdrop
    var carousel = (flow ?? baseTheme?.carousel).mergingFlowStep(contentTheme, stepTheme, stepBackdrop)
    if step.stepType == .modal, let alignment = step.settings?.position?.modalAlignment {
        carousel.general = GeneralStyle(contentAlignment: alignment, fontFamily: carousel.fontFamily)
    }
    return ThemeData(
        carousel: carousel,
        slideOut: (flow ?? baseTheme?.slideOut).mergingFlowStep(contentTheme, stepTheme, stepBackdrop),
        survey: nil,
        tooltip: (flow ?? baseTheme?.tooltip).mergingFlowStep(contentTheme, stepTheme, stepBackdrop)
    )
}

private extension Optional where Wrapped == ExperienceTheme {
    /// `merging` over this base, then the step's `settings.backdrop` above every backdrop layer.
    /// Both use the 0–100 opacity scale, so its fields copy as they are.
    func mergingFlowStep(
        _ contentTheme: ExperienceTheme?,
        _ stepTheme: ExperienceTheme?,
        _ stepBackdrop: FlowBackdrop?
    ) -> ExperienceTheme {
        var merged = merging(globalTheme: contentTheme, stepTheme: stepTheme)
        let settingsBackdrop = stepBackdrop.map {
            Backdrop(color: $0.color, enabled: $0.enabled, opacity: $0.opacity)
        }
        merged.backdrop = merged.backdrop.merging(global: nil, step: settingsBackdrop)
        return merged
    }
}

extension Optional where Wrapped == SurveyTheme {
    /// Missing groups still produce styles with nil fields, matching experience rendering defaults.
    func merging(_ surveyTheme: SurveyTheme?) -> SurveyTheme {
        SurveyTheme(
            general: SurveyGeneral(
                position: surveyTheme?.general?.position ?? self?.general?.position,
                primaryColor: surveyTheme?.general?.primaryColor ?? self?.general?.primaryColor,
                backgroundColor: surveyTheme?.general?.backgroundColor ?? self?.general?.backgroundColor,
                cornerRadius: surveyTheme?.general?.cornerRadius ?? self?.general?.cornerRadius
            ),
            font: SurveyFont(
                fontFamily: surveyTheme?.font?.fontFamily ?? self?.font?.fontFamily,
                fontColor: surveyTheme?.font?.fontColor ?? self?.font?.fontColor,
                colorType: surveyTheme?.font?.colorType ?? self?.font?.colorType
            ),
            progress: (self?.progress).merging(global: surveyTheme?.progress, step: nil),
            backdrop: (self?.backdrop).merging(global: surveyTheme?.backdrop, step: nil)
        )
    }
}

private extension Optional where Wrapped == ButtonStyle {
    func merging(global: ButtonStyle?, step: ButtonStyle?) -> ButtonStyle {
        ButtonStyle(
            backgroundColor: step?.backgroundColor ?? global?.backgroundColor ?? self?.backgroundColor,
            labelColor: step?.labelColor ?? global?.labelColor ?? self?.labelColor,
            borderColor: step?.borderColor ?? global?.borderColor ?? self?.borderColor,
            borderWidth: step?.borderWidth ?? global?.borderWidth ?? self?.borderWidth,
            borderRadius: step?.borderRadius ?? global?.borderRadius ?? self?.borderRadius
        )
    }
}

private extension Optional where Wrapped == ColorsStyle {
    func merging(global: ColorsStyle?, step: ColorsStyle?) -> ColorsStyle {
        ColorsStyle(
            backgroundColor: step?.backgroundColor ?? global?.backgroundColor ?? self?.backgroundColor,
            textColor: step?.textColor ?? global?.textColor ?? self?.textColor,
            titleColor: step?.titleColor ?? global?.titleColor ?? self?.titleColor
        )
    }
}

private extension Optional where Wrapped == DismissContentStyle {
    func merging(global: DismissContentStyle?, step: DismissContentStyle?) -> DismissContentStyle {
        DismissContentStyle(
            color: step?.color ?? global?.color ?? self?.color,
            colorType: step?.colorType ?? global?.colorType ?? self?.colorType,
            enabled: step?.enabled ?? global?.enabled ?? self?.enabled
        )
    }
}

private extension Optional where Wrapped == GeneralStyle {
    func merging(global: GeneralStyle?, step: GeneralStyle?) -> GeneralStyle {
        GeneralStyle(
            contentAlignment: step?.contentAlignment ?? global?.contentAlignment ?? self?.contentAlignment,
            fontFamily: step?.fontFamily ?? global?.fontFamily ?? self?.fontFamily
        )
    }
}

private extension Optional where Wrapped == ProgressStyle {
    /// `style` resolves within each layer before merging, so a lower layer's `style` never overrides a higher
    /// layer that only sets `type`.
    func merging(global: ProgressStyle?, step: ProgressStyle?) -> ProgressStyle {
        ProgressStyle(
            color: step?.color ?? global?.color ?? self?.color,
            colorType: step?.colorType ?? global?.colorType ?? self?.colorType,
            enabled: step?.enabled ?? global?.enabled ?? self?.enabled,
            type: step?.type ?? global?.type ?? self?.type,
            style: step?.layerStyle ?? global?.layerStyle ?? self?.layerStyle
        )
    }
}

private extension ProgressStyle {
    /// A layer's own progress style: a Flow theme names it `style`, a survey theme `type`. Resolved within
    /// each layer before layers merge, so a lower layer's `style` never overrides a higher layer's `type`.
    var layerStyle: ProgressStyleType? { style ?? type }
}

private extension Optional where Wrapped == Backdrop {
    func merging(global: Backdrop?, step: Backdrop?) -> Backdrop {
        Backdrop(
            color: step?.color ?? global?.color ?? self?.color,
            enabled: step?.enabled ?? global?.enabled ?? self?.enabled,
            opacity: step?.opacity ?? global?.opacity ?? self?.opacity
        )
    }
}
