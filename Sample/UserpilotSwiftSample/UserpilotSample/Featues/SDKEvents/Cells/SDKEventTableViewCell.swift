//
//  EventsTableViewCell.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/11/2024.
//

import UIKit

class SDKEventTableViewCell: UITableViewCell, ReusableTableCellView, TableViewCellFromNib {

    @IBOutlet weak var eventType: UILabel!
    @IBOutlet weak var eventName: UILabel!
    @IBOutlet weak var eventProperties: UILabel!
    @IBOutlet weak var containerView: UIView!

    func bindCell(_ sdkEvent: UserpilotSDKEvent) {
        eventType.text = sdkEvent.analytic
        eventName.text = sdkEvent.value
        if sdkEvent.analytic == "Identify" {
            let settings = UserpilotManager.shared.settings()
            if let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: .withoutEscapingSlashes) {
                eventProperties.text = String(data: jsonData, encoding: .utf8)
            }
        } else {
            if let properties = sdkEvent.properties,
               let jsonData = try? JSONSerialization.data(
                withJSONObject: properties, options: .withoutEscapingSlashes) {
                eventProperties.text = String(data: jsonData, encoding: .utf8)
            }
        }

        if sdkEvent.analytic == "Identify" ||
            sdkEvent.analytic == "Screen" ||
            sdkEvent.analytic == "Event" {
            containerView.backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.9, alpha: 0.15)
        } else {
            containerView.backgroundColor = UIColor(red: 0.9, green: 0.12, blue: 0.39, alpha: 0.05)
        }
    }

}
