//
//  EventsTableViewCell.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 16/11/2024.
//

import UIKit

class SDKEventTableViewCell: UITableViewCell, ReusableTableCellView, TableViewCellFromNib {

    @IBOutlet weak var eventType: UILabel!
    @IBOutlet weak var eventName: UILabel!
    @IBOutlet weak var eventProperties: UILabel!

    func bindCell(_ sdkEvent: UserPilotSDKEvents) {
        eventType.text = sdkEvent.analytic.rawValueString
        eventName.text = sdkEvent.value
        if sdkEvent.analytic == .identify {
            let settings = UserPilotManager.shared.settings()
            if let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: .withoutEscapingSlashes) {
                // swiftlint:disable:next non_optional_string_data_conversion
                eventProperties.text = String(data: jsonData, encoding: .utf8)
            }
        } else {
            if let properties = sdkEvent.properties,
               let jsonData = try? JSONSerialization.data(
                withJSONObject: properties, options: .withoutEscapingSlashes) {
                // swiftlint:disable:next non_optional_string_data_conversion
                eventProperties.text = String(data: jsonData, encoding: .utf8)
            }
        }
    }

}
