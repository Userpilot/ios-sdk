//
//  CarouselView.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 26/08/2024.
//

import Foundation
import UIKit

class CarouselView: UIView, NibLoadable {

    var view: UIView!
    @IBOutlet weak var stackViewContainer: UIStackView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        view = loadViewFromNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        view = loadViewFromNib()
    }

    func bindViews() {
        // Create a UILabel
        let label = UILabel()
        label.text = "Hello, StackView!"
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 18)
        label.textAlignment = .center

        // Create a UIImageView
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "star.fill")
        imageView.tintColor = .systemYellow
        imageView.contentMode = .scaleAspectFit
        // Set a fixed size for the image
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 50).isActive = true

        stackViewContainer.addSubview(label)
        stackViewContainer.addSubview(imageView)
    }

}

protocol NibLoadable: AnyObject {
    static var nibName: String { get }
}

extension NibLoadable where Self: UIView {
    static var nibName: String {
        return NSStringFromClass(self).components(separatedBy: ".").last!
    }
}

extension NibLoadable where Self: UIView {
    func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: Self.nibName, bundle: bundle)
        // swiftlint:disable force_cast
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        // swiftlint:enable force_cast

        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
        return view
    }
}
