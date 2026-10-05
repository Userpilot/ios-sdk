//
//  UPCollectionViewLayout.swift
//  Userpilot SDK
//
//  Created by Userpilot on 30/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  A custom UICollectionViewFlowLayout subclass that flips its layout direction
//  horizontally when the device is in an RTL (right-to-left) environment.
//

import UIKit

class UPCollectionViewLayout: UICollectionViewFlowLayout {
    open override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        return true
    }
}
