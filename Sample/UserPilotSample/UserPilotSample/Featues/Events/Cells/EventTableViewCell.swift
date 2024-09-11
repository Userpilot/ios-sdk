//
//  EventTableViewCell.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/09/2024.
//

import UIKit

class EventTableViewCell: UITableViewCell, ReusableTableCellView, TableViewCellFromNib {

    @IBOutlet weak var eventName: UILabel!
    @IBOutlet weak var eventTitle: UITextField!
    @IBOutlet weak var eventValue: UITextField!

    var onTrackEvent: ((String?, String?) -> Void)?

    func bindCell(_ indexPath: IndexPath) {
    }

    @IBAction func onTrackEventButtonClicked(_ sender: UIButton) {
        onTrackEvent?(eventTitle.text, eventValue.text)
    }

}
