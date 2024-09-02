//
//  OnBoardingViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 26/08/2024.
//

import Foundation
import UIKit

class OnBoardingViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.onBoardingCollectionViewLayout()
            collectionView.register(cellFromNib: CarouselCollectionViewCell.self)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDelegateFlowLayout
extension OnBoardingViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let carouselCollectionViewCell: CarouselCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)
        carouselCollectionViewCell.bindUI()
        return carouselCollectionViewCell
    }

}
