//
//  EventTableViewCell.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/09/2024.
//

import UIKit

class EventTableViewCell: UITableViewCell, ReusableTableCellView, TableViewCellFromNib {

    @IBOutlet weak var eventName: UILabel!
    @IBOutlet weak var eventTitle: UITextField! {
        didSet {
            eventTitle.delegate = self
        }
    }
    @IBOutlet weak var eventValue: UITextField! {
        didSet {
            eventValue.delegate = self
        }
    }

    var onTrackEvent: ((String?, String?) -> Void)?

    func bindCell(_ indexPath: IndexPath) {
        eventName.text = "\("event_title".localized) \(indexPath.row)"
    }

    @IBAction func onTrackEventButtonClicked(_ sender: UIButton) {
        onTrackEvent?(eventTitle.text, eventValue.text)
    }

}

// MARK: - UITextFieldDelegate

extension EventTableViewCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
