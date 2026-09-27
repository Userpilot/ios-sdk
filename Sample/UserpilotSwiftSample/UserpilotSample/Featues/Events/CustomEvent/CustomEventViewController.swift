//
//  CustomEventViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/09/2024.
//

import Foundation
import UIKit

class CustomEventViewController: BaseViewController {

    // MARK: - IBOutlet

    @IBOutlet weak var textFieldEventName: UITextField! {
        didSet {
            textFieldEventName.delegate = self
        }
    }
    @IBOutlet weak var eventPropertiesStackView: UIStackView!
    @IBOutlet weak var trackEventButton: UIButton!

    internal var eventPropertiesViews: [String: PropertyView] = [:]

    private lazy var advanceEventButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Advance event", for: .normal)
        button.applyLiquidGlassStyle(.regular, title: "Advance event")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(onAdvanceEventTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Override

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Track event"
        wrapPrimaryScrollContentInCard()
        installAdvanceEventButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("custom events")
    }

    // MARK: - IBActions

    @IBAction func onTrackEventButtonClicked(_ sender: UIButton) {
        trackEvent()
    }

    @IBAction func onAddEventProperty(_ sender: UIButton) {
        showAddEventPropertyDiaog()
    }

    @objc private func onAdvanceEventTapped() {
        FlowRoutingManager.shared.openViewController(EventsViewController.newInstance())
    }

    private func installAdvanceEventButton() {
        let trackButton = trackEventButton
            ?? view.subviews.compactMap({ $0 as? UIButton }).first
        guard let trackButton else { return }

        view.addSubview(advanceEventButton)

        // Move the track button's bottom constraint onto the advance button.
        let trackBottomConstraints = view.constraints.filter {
            ($0.firstItem as? UIView) == trackButton && $0.firstAttribute == .bottom
                || ($0.secondItem as? UIView) == trackButton && $0.secondAttribute == .bottom
        }
        NSLayoutConstraint.deactivate(trackBottomConstraints)

        NSLayoutConstraint.activate([
            advanceEventButton.leadingAnchor.constraint(equalTo: trackButton.leadingAnchor),
            advanceEventButton.trailingAnchor.constraint(equalTo: trackButton.trailingAnchor),
            advanceEventButton.topAnchor.constraint(equalTo: trackButton.bottomAnchor, constant: 8),
            advanceEventButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

}

// MARK: - Helper methods

extension CustomEventViewController {

    private func trackEvent() {
        guard let eventName = textFieldEventName.text, !eventName.isEmpty
        else { return }
        var eventProperties: [String: String] = [:]
        for (_, propertyView) in eventPropertiesViews {
            eventProperties[propertyView.getParams().0] = propertyView.getParams().1
        }
        UserpilotManager.shared.track(eventName: eventName, properties: eventProperties)
    }

}

// MARK: - Event property methods

extension CustomEventViewController {

    internal func showAddEventPropertyDiaog(_ propertyTitle: String = "", _ propertyValue: String = "") {
        DialogManager.shared().showAddPropertyDialogViewController(propertyTitle: propertyTitle,
                                                  propertyValue: propertyValue,
                                                  doneButtonHandler: { [weak self] propertyTitle, propertyValue in
            guard let self else { return }
            self.addUserProperty(propertyTitle, propertyValue)
        })
    }

    private func addUserProperty(_ propertyTitle: String, _ propertyValue: String?) {
        let propertyView = PropertyView()

        propertyView.onEditProperty = { [weak self] propertyTitle, propertyValue in
            guard let self else { return }
            self.showAddEventPropertyDiaog(propertyTitle, propertyValue)
        }

        propertyView.onDeleteProperty = { [weak self] propertyTitle, _ in
            guard let self else { return }
            if let view = eventPropertiesViews[propertyTitle] {
                self.eventPropertiesStackView.removeItemFromStackView(view)
                view.removeFromSuperview()
                eventPropertiesViews.removeValue(forKey: propertyTitle)
            }
        }
        if let view = eventPropertiesViews[propertyTitle] {
            self.eventPropertiesStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
            eventPropertiesViews.removeValue(forKey: propertyTitle)
        }
        propertyView.bindData(propertyName: propertyTitle, propertyValue: propertyValue)
        eventPropertiesStackView.addItemToStackView(propertyView)
        eventPropertiesViews[propertyTitle] = propertyView
    }
}

// MARK: - UITextFieldDelegate

extension CustomEventViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Instance

extension CustomEventViewController {

    static func newInstance() -> CustomEventViewController {
        return CustomEventViewController()
    }

}
