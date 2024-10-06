//
//  File.swift
//  
//
//  Created by Motasem Hamed on 01/10/2024.
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

extension UICollectionViewCell {
    static var identifier: String {
        return String(describing: self)
    }
}
