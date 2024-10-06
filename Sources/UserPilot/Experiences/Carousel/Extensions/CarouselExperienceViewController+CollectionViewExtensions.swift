//
//  File.swift
//  
//
//  Created by Motasem Hamed on 01/10/2024.
//

import Foundation
import UIKit

// MARK: - UICollectionViewDelegate, UICollectionViewDelegateFlowLayout
extension CarouselExperienceViewController: UICollectionViewDataSource,
                                            UICollectionViewDelegate,
                                            UICollectionViewDelegateFlowLayout,
                                            UIScrollViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return carouselExperienceViewModel.carouselStepsCount
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard
            let stepCollectionViewCell: StepCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath),
            let step = carouselExperienceViewModel.carouselContent?.steps[safe: indexPath.item],
            let themeData = carouselExperienceViewModel.mergedTheme[safe: indexPath.item]
        else {
            return UICollectionViewCell()
        }

        stepCollectionViewCell.bindStep(step,
                                        withThemeData: themeData,
                                        andExperienceContentListener: self,
                                        andImageLoader: carouselExperienceViewModel.imageLoader)
        return stepCollectionViewCell
    }

    // Set size for each item
      func collectionView(_ collectionView: UICollectionView,
                          layout collectionViewLayout: UICollectionViewLayout,
                          sizeForItemAt indexPath: IndexPath) -> CGSize {
          return CGSize(width: UIScreen.main.bounds.width, height: collectionView.frame.size.height)
      }

    // MARK: - UICollectionViewDelegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Calculate the current page index
        let step = Int(scrollView.contentOffset.x / collectionView.frame.width)
        onNewStepViewed(step)
    }

}

extension CarouselExperienceViewController: ExperienceContentProtocol {

}
