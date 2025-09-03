//
//  PropertyView.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 15/09/2024.
//

import Foundation
import UIKit

class PropertyView: UIView, NibLoadable {

    // MARK: - IBOutlet

    var view: UIView!
    @IBOutlet weak var propertyName: UILabel!
    @IBOutlet weak var propertyValue: UILabel!

    var onEditProperty: (String, String) -> Void = { _, _ in }
    var onDeleteProperty: (String, String) -> Void = { _, _ in }

    // MARK: - Override

    override init(frame: CGRect) {
        super.init(frame: frame)
        view = loadViewFromNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        view = loadViewFromNib()
    }

    // MARK: - IBAction
    @IBAction func onEditPropertyButtonClicked(_ sender: UIButton) {
        onEditProperty(propertyName.text ?? "", propertyValue.text ?? "")
    }

    @IBAction func onDeletePropertyButtonClicked(_ sender: UIButton) {
        onDeleteProperty(propertyName.text ?? "", propertyValue.text ?? "")
    }

    // MARK: - Helper methods
    func bindData(propertyName: String, propertyValue: String) {
        self.propertyName.text = propertyName
        self.propertyValue.text = propertyValue
    }

    func getParams() -> (String, String) {
        return (propertyName.text ?? "", propertyValue.text ?? "")
    }

}
