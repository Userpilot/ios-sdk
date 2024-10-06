//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit

/// A custom image view that configures itself based on a `Line` object.
internal class UPImageView: UIImageView {

    // Stores the `Line` configuration used to set up the view.
    private var line: Line?

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    /// Common initializer for setting up view properties.
    private func initializeView() {
        contentMode = .scaleAspectFit
        translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Setup Methods

    /**
     Configures the image view based on the provided `Line` data.
     
     - Parameter line: The `Line` object containing configuration and attributes for the image or icon to display.
     */
    func setupView(line: Line, imageLoader: ImageLoading) {
        self.line = line

        guard let attrs = line.attrs else { return }

        let url = line.type == .image ? attrs.src : attrs.icon
        guard let url = url else { return }

        imageLoader.loadImage(target: self,
                              url: url,
                              placeholder: .lightGray,
                              blurHash: "",
                              size: CGSize(width: 200, height: 200))
    }
}
