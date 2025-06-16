//
//  UICollectionView+Extension.swift
//
//
//  Created by Motasem Hamed on 01/10/2024.
//
//  [Brief Description]
//  UICollectionView+Extension file contains an extension for the `UIViewController` class, providing helper methods
//  for obtaining class names, capturing screen events, and swizzling the `viewDidAppear` method
//  to include custom tracking logic.
//

import Foundation
import UIKit

internal extension UICollectionView {

    func dequeueReusableCell<T: UICollectionViewCell>(for indexPath: IndexPath) -> T? {
        return dequeueReusableCell(withReuseIdentifier: T.identifier, for: indexPath) as? T
    }

    var currentIndex: Int {
        return self.indexPathsForVisibleItems.first?.item ?? 0
    }

    func scrollToNextItem() {
        // Get the current index path of the visible item
        guard let visibleIndexPath = self.indexPathsForVisibleItems.first else { return }

        let nextItem = visibleIndexPath.item + 1
        let nextIndexPath = IndexPath(item: nextItem, section: visibleIndexPath.section)

        // Ensure that the next item is within the bounds of the data source
        if nextItem < self.numberOfItems(inSection: visibleIndexPath.section) {
            self.scrollToItem(at: nextIndexPath, at: .centeredHorizontally, animated: true)
        }
    }
}

internal extension UICollectionViewCell {
    static var identifier: String {
        return String(describing: self)
    }

    func topSafeAreaHeight() -> CGFloat {
        if  isLandscape {
            return CGFloat(70)
        } else {
            if let window = self.window {
                return window.safeAreaInsets.top
            } else if let collectionView = self.superview as? UICollectionView,
                      let window = collectionView.window {
                return window.safeAreaInsets.top
            }
            return 0
        }
    }
}
