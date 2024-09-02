//
//  UICollectionView+Data.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 01/09/2024.
//

import Foundation
import UIKit

/// DequeueReusableCell
extension UICollectionView {

    func dequeueReusableCell<T: UICollectionViewCell>(for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(
            withReuseIdentifier: T.reuseIdentifier,
            for: indexPath) as? T else {
            fatalError("Could not dequeue view with identifier: \(T.reuseIdentifier)")
        }
        return cell
    }

}

/// Register cells
extension UICollectionView {

    func register<T: CollectionViewCellFromNib>(cellFromNib: T.Type) {
        register(T.nib, forCellWithReuseIdentifier: T.reuseIdentifier)
    }

}

/// ReuseIdentifier
extension UICollectionReusableView {
    static var reuseIdentifier: String {
        return String(describing: Self.self)
    }
}

/// UICollectionViewFlowLayout
extension UICollectionView {

    func onBoardingCollectionViewLayout() {
        let flowLayout: UICollectionViewFlowLayout =  UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: Screen.width, height: self.frame.height)
        flowLayout.sectionInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.scrollDirection = .horizontal
        self.collectionViewLayout = flowLayout
        self.isPagingEnabled = true
    }
}

///
protocol CollectionViewCellFromNib: UICollectionViewCell {

}

extension CollectionViewCellFromNib {
    static var nib: UINib {
        return UINib(nibName: String(describing: Self.self), bundle: nil)
    }
}
