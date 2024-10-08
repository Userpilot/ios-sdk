//
//  CarouselExperienceViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This class manages the carousel experience within the application.
//  It conforms to `UICollectionViewDataSource`, `UICollectionViewDelegate`,
//  `UICollectionViewDelegateFlowLayout`, and `UIScrollViewDelegate` protocols
//  to handle the display and interaction of carousel item.
//

import Foundation
import UIKit

// MARK: - UICollectionViewDelegate, UICollectionViewDelegateFlowLayout

extension CarouselExperienceViewController: UICollectionViewDataSource,
                                            UICollectionViewDelegate,
                                            UICollectionViewDelegateFlowLayout,
                                            UIScrollViewDelegate {

    /// Returns the number of items in the specified section of the collection view.
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return carouselExperienceViewModel.carouselStepsCount
    }

    /// Returns a cell configured for the item at the specified index path.
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Attempt to dequeue a reusable cell
        guard
            let stepCollectionViewCell: StepCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath),
            let step = carouselExperienceViewModel.carouselContent?.steps[safe: indexPath.item],
            let themeData = carouselExperienceViewModel.mergedTheme[safe: indexPath.item]
        else {
            // Return an empty cell if configuration fails
            return UICollectionViewCell()
        }

        // Bind the step data to the cell
        stepCollectionViewCell.bindStep(step,
                                        withThemeData: themeData,
                                        andExperienceContentListener: self,
                                        andImageLoader: carouselExperienceViewModel.imageLoader)
        return stepCollectionViewCell
    }

    /// Returns the size for each item in the collection view.
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Return the full width of the screen with the height of the collection view
        return CGSize(width: UIScreen.main.bounds.width, height: collectionView.frame.size.height)
    }

    /// Called when the user finishes scrolling and the scrolling stops.
    ///
    /// - Parameter scrollView: The scroll view that stopped scrolling.
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let step = Int(scrollView.contentOffset.x / collectionView.frame.width)
        onNewStepViewed(step)
    }
}

// MARK: - ExperienceContentProtocol Conformance

extension CarouselExperienceViewController: ExperienceContentProtocol {

}
