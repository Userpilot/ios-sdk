//
//  File.swift
//
//
//  Created by Motasem Hamed on 30/09/2024.
//

import Foundation
import UIKit

internal extension CarouselExperienceViewController {

    func setupGeneralStyle() {
        let theme = carouselExperienceViewModel.mergedTheme[collectionView.currentIndex]

        self.view.backgroundColor = theme.backgroundColor

        if theme.isDismissButtonEnabled {
            buttonDismiss.setupView(style: theme)
        } else {
            buttonDismissContainerView.isHidden = true
        }

        viewStepsProgress.setupView(stepsCount: carouselExperienceViewModel.carouselContent?.steps.count ?? 0,
                                    style: theme)
    }

    func bindActionButton(_ index: Int) {
        guard
            let theme = carouselExperienceViewModel.mergedTheme[safe: index],
            let step = carouselExperienceViewModel.carouselContent?.steps[safe: index],
            let lastSection = step.sections.last,
            let button = lastSection.lines.last,
            button.type == .button
        else {
            return
        }
        buttonAction.setupViews(
            line: button,
            action: step.buttonAction,
            style: theme
        ) { [weak self] action in
            guard let self = self else { return }
            if self.isLastStep() {
                dismiss(animated: true, completion: {
                    if action.deepLink != nil {
                        self.carouselExperienceViewModel.onDeepLinkTriggered()
                    }
                    self.carouselExperienceViewModel.onExperienceCompleted()
                })
            }
        }

    }

    func isLastStep() -> Bool {
        let index = collectionView.currentIndex
        if index == carouselExperienceViewModel.carouselStepsCount - 1 {
            return true
        } else {
            collectionView.scrollToNextItem()
            onNewStepViewed(index + 1)
            return false
        }
    }

    func onNewStepViewed(_ step: Int) {
        viewStepsProgress.setCurrentStep(step)
        bindActionButton(step)
    }
}
