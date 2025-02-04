//
//  UPLikertView+CollectionView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This extension provides the implementation for UICollectionView's DataSource and Delegate methods.
//  It is responsible for configuring and handling interactions with the collection view in the UPLikertView class,
//  such as displaying the Likert scale items, selecting them, and handling layout customization.
//

import UIKit

// MARK: - Collection View DataSource and Delegate

extension UPLikertView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - DataSource Methods

    /// Returns the number of items in the collection view.
    /// - Parameter section: The section in the collection view (used for multiple sections, but here it's always 1).
    /// - Returns: The count of rating items to display.
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return ratingItems.count
    }

    /// Configures and returns the cell for the item at the given index path.
    /// - Parameter collectionView: The collection view requesting the cell.
    /// - Parameter indexPath: The index path specifying the location of the cell.
    /// - Returns: The configured UICollectionViewCell.
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Attempt to dequeue a reusable cell
        guard
            let likertCollectionViewCell: LikertCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath),
            let surveyTheme = self.surveyTheme
        else {
            // Return an empty cell if dequeue fails
            return UICollectionViewCell()
        }

        // Bind the rating item data to the cell
        likertCollectionViewCell.bindCell(ratingItem: ratingItems[indexPath.item],
                                          surveyTheme: surveyTheme,
                                          isRTL: isRTL)
        return likertCollectionViewCell
    }

    // MARK: - Delegate Methods

    /// Handles the selection of a cell in the collection view.
    /// Updates the `isSelected` property of rating items based on the selected cell.
    /// Also triggers the view state change.
    /// - Parameter collectionView: The collection view where the selection occurred.
    /// - Parameter indexPath: The index path of the selected cell.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Mark rating items as selected up to the selected index
        for index in ratingItems.indices {
            ratingItems[index].isSelected = index <= indexPath.row
        }

        // Notify the view state delegate about the validity of the answer
        viewStateProtocol?.onViewStateChanged(isValid: isValidAnswer())

        // Reload the collection view to reflect the updated selection
        collectionView.reloadData()
    }

    /// Returns the size of each item in the collection view.
    /// - Parameter collectionView: The collection view requesting the item size.
    /// - Parameter collectionViewLayout: The layout used to arrange the items.
    /// - Parameter indexPath: The index path of the item whose size is being requested.
    /// - Returns: The size of the item at the given index path.
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // The height is fixed at 40, and the width is calculated dynamically based on the `itemWidth`
        return CGSize(width: itemWidth, height: 40)
    }

}

// MARK: - Custom Collection View Layout for Centering

/// Custom UICollectionViewFlowLayout subclass to center the collection view cells within the available width.
internal class CenteredCollectionViewLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }

        // Group the attributes by their Y position to handle each row of items separately
        let groupedAttributes = Dictionary(grouping: attributes, by: { $0.frame.origin.y })

        // Adjust the X position of each item in each row to center the items
        for (_, rowAttributes) in groupedAttributes {
            let totalWidth = rowAttributes.reduce(0) { $0 + $1.frame.width }
            let spacing = minimumInteritemSpacing * CGFloat(rowAttributes.count - 1)
            let totalRowWidth = totalWidth + spacing
            let horizontalInset = max(0, (collectionView!.bounds.width - totalRowWidth) / 2)
            var xOffset = horizontalInset
            for attribute in rowAttributes {
                attribute.frame.origin.x = xOffset
                xOffset += attribute.frame.width + minimumInteritemSpacing
            }
        }

        return attributes
    }
}
