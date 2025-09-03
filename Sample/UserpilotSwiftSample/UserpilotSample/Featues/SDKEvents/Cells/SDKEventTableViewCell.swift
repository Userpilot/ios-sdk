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
            containerView.backgroundColor = UIColor(red: 103/255.0, green: 101/255.0, blue: 232/255.0, alpha: 0.102)
        } else {
            containerView.backgroundColor = UIColor(red: 233/255.0, green: 30/255.0, blue: 99/255.0, alpha: 0.027)
        }
    }

}
