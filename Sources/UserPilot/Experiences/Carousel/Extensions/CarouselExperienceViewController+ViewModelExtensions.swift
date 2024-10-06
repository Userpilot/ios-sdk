//
//  File.swift
//  
//
//  Created by Motasem Hamed on 30/09/2024.
//

import Foundation

internal extension CarouselExperienceViewController {

    func bindViewModel() {
        carouselExperienceViewModel.bindData = { [weak self] in
            self?.setupGeneralStyle()
            self?.collectionView.reloadData()
            self?.bindActionButton(0)
        }

        carouselExperienceViewModel.dismissViewController = { [weak self] in
            self?.dismiss(animated: true)
        }
        carouselExperienceViewModel.onStart()
    }

}
