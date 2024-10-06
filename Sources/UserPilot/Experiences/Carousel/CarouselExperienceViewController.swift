//
//  File.swift
//  
//
//  Created by Motasem Hamed on 30/09/2024.
//

import Foundation
import UIKit

internal class CarouselExperienceViewController: UIViewController {

    @IBOutlet internal weak var buttonDismissContainerView: UIView!
    @IBOutlet internal weak var buttonDismiss: UPCloseButton!
    @IBOutlet internal weak var buttonAction: UPButtonView!
    @IBOutlet internal weak var viewStepsProgress: UPStepsProgressView!
    @IBOutlet internal weak var collectionView: UICollectionView! {
        didSet {
            collectionView.register(StepCollectionViewCell.self,
                                    forCellWithReuseIdentifier: StepCollectionViewCell.identifier)
            collectionView.bounces = false
            collectionView.alwaysBounceHorizontal = false
            collectionView.alwaysBounceVertical = false

        }
    }

    internal let carouselExperienceViewModel: CarouselExperienceViewModel

    init(carouselExperienceViewModel: CarouselExperienceViewModel) {
        self.carouselExperienceViewModel = carouselExperienceViewModel
        super.init(nibName: "CarouselExperienceViewController", bundle: .module)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        bindViewModel()
        isModalInPresentation = true
    }

}

internal extension CarouselExperienceViewController {

    @objc func closeButtonTapped() {
        dismiss(animated: true)
    }
}
