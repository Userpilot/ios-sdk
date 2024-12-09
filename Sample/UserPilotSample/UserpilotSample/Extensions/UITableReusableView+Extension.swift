//
//  UITableReusableView+Extension.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/09/2024.
//
//  - The `UITableView` extension adds methods for registering and dequeuing cells.
//  - The `ReusableTableCellView` protocol defines a reusable identifier for cells.
//  - The `TableViewCellFromNib` protocol supports cells instantiated from nib files.
//

import Foundation
import UIKit

extension UITableView {
    func register<T: TableViewCellFromNib>(cellFromNib: T.Type) where T: ReusableTableCellView {
        register(T.nib, forCellReuseIdentifier: T.reuseIdentifier)
    }

    func dequeueReusableCell<T: UITableViewCell>(for indexPath: IndexPath) -> T where T: ReusableTableCellView {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Could not dequeue cell with identifier: \(T.reuseIdentifier)")
        }
        return cell
    }
}

protocol ReusableTableCellView: AnyObject {
    static var reuseIdentifier: String { get }
}

extension ReusableTableCellView where Self: UIView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

protocol TableViewCellFromNib: UITableViewCell {

}

extension TableViewCellFromNib {
    static var nib: UINib {
        return UINib(nibName: String(describing: Self.self), bundle: nil)
    }
}
