//
//  DatePickerDialog.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//
//  [Brief Description]
//  A customizable date picker dialog view.
//

import Foundation
import UIKit

private extension Selector {
    static let buttonTapped = #selector(DatePickerDialog.buttonTapped)
}

internal class DatePickerDialog: UIView {
    public typealias DatePickerCallback = ( Date? ) -> Void

    // MARK: - Constants
    private let kDefaultButtonHeight: CGFloat = 50
    private let kDefaultButtonSpacerHeight: CGFloat = 1
    let kCornerRadius: CGFloat = 7
    private let kDoneButtonTag: Int = 1

    // MARK: - Views
    private var dialogView: UIView!
    private var titleLabel: UILabel!
    open var datePicker: UIDatePicker!
    private var cancelButton: UPAlertActionButton!
    private var doneButton: UPAlertActionButton!

    // MARK: - Variables
    private var defaultDate: Date?
    private var datePickerMode: UIDatePicker.Mode?
    private var callback: DatePickerCallback?
    var showCancelButton: Bool = false
    var locale: Locale?

    private var textColor: UIColor!
    var buttonColor: UIColor!
    private var font: UIFont!

    /// Decides whether this dialog's container renders as Liquid Glass.
    ///
    /// Assigned before `show(...)` because the container is styled during presentation.
    internal var glassResolver: GlassCapabilityResolving? {
        didSet {
            rebuildForResolverChange(from: oldValue)
        }
    }

    /// The survey card's background colour, which this dialog floats above.
    ///
    /// Taken from the card rather than the system, for the same reason the country picker menu does
    /// it: a survey themed dark has a dark card whatever the device's appearance is, and a light
    /// dialog over it reads as a hole. `nil` keeps the pre-existing grey treatment.
    ///
    /// An init parameter rather than a property because `setupView()` runs from `init`, so a value
    /// assigned afterwards would arrive too late for the container it builds.
    var themeBackground: UIColor?

    // MARK: - Dialog initialization
    @objc public init(
        textColor: UIColor = .black,
        buttonColor: UIColor = .black,
        font: UIFont = .boldSystemFont(ofSize: 15),
        locale: Locale = Locale.current,
        showCancelButton: Bool = true,
        themeBackground: UIColor? = nil) {
        let size = UIScreen.main.bounds.size
        super.init(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        self.textColor = textColor
        self.buttonColor = buttonColor
        self.font = font
        self.showCancelButton = showCancelButton
        self.locale = locale
        self.themeBackground = themeBackground
        setupView()
    }

    @objc required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func setupView() {
        dialogView = createContainerView()

        dialogView?.layer.shouldRasterize = true
        dialogView?.layer.rasterizationScale = UIScreen.main.scale

        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale

        dialogView?.layer.opacity = 0.5
        dialogView?.layer.transform = CATransform3DMakeScale(1.3, 1.3, 1)

        backgroundColor = .clear

        if let dialogView = dialogView {
            addSubview(dialogView)
        }
    }

    /// Create the dialog view, and animate opening the dialog
    open func show(
        title: String = "Select date",
        doneButtonTitle: String = "Select",
        cancelButtonTitle: String = "Dismiss",
        defaultDate: Date = Date(),
        minimumDate: Date? = nil, maximumDate: Date? = nil,
        datePickerMode: UIDatePicker.Mode = .date,
        callback: @escaping DatePickerCallback
    ) {
        self.titleLabel.text = title
        self.doneButton.setTitle(doneButtonTitle, for: .normal)
        if showCancelButton { self.cancelButton.setTitle(cancelButtonTitle, for: .normal) }
        self.datePickerMode = datePickerMode
        self.callback = callback
        self.defaultDate = defaultDate
        self.datePicker.datePickerMode = self.datePickerMode ?? UIDatePicker.Mode.date
        self.datePicker.date = self.defaultDate ?? Date()
        self.datePicker.maximumDate = maximumDate
        self.datePicker.minimumDate = minimumDate
        if #available(iOS 13.4, *) {
            self.datePicker.preferredDatePickerStyle = .wheels
        }
        if let locale = self.locale { self.datePicker.locale = locale }

        /* Add dialog to main window */
        guard let window = getWindow() else { return }
        window.addSubview(self)
        window.bringSubviewToFront(self)
        window.endEditing(true)

        /* Anim */
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                self.backgroundColor = self.backdropColor
                self.dialogView?.layer.opacity = 1
                self.dialogView?.layer.transform = CATransform3DMakeScale(1, 1, 1)
            }
        )
    }

    /// Dialog close animation then cleaning and removing the view from the parent
    private func close() {
        let currentTransform = self.dialogView.layer.transform

        let startRotation = (self.value(forKeyPath: "layer.transform.rotation.z") as? NSNumber) as? Double ?? 0.0
        let rotation = CATransform3DMakeRotation((CGFloat)(-startRotation + .pi * 270 / 180), 0, 0, 0)

        self.dialogView.layer.transform = CATransform3DConcat(rotation, CATransform3DMakeScale(1, 1, 1))
        self.dialogView.layer.opacity = 1

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [],
            animations: {
                self.backgroundColor = .clear
                let transform = CATransform3DConcat(currentTransform, CATransform3DMakeScale(0.6, 0.6, 1))
                self.dialogView.layer.transform = transform
                self.dialogView.layer.opacity = 0
            }
            // swiftlint:disable:next multiple_closures_with_trailing_closure
        ) { _ in
            for view in self.subviews {
                view.removeFromSuperview()
            }

            self.removeFromSuperview()
            self.setupView()
        }
    }

    /// Creates the container view here: create the dialog, then add the custom content and buttons
    private func createContainerView() -> UIView {
        let screenSize = UIScreen.main.bounds.size
        let dialogSize = CGSize(width: 330, height: 230 + kDefaultButtonHeight + kDefaultButtonSpacerHeight)

        // For the black background
        self.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)

        // This is the dialog's container; we attach the custom content and the buttons to this one
        let container = UIView(frame: CGRect(
            x: (screenSize.width - dialogSize.width) / 2,
            y: (screenSize.height - dialogSize.height) / 2,
            width: dialogSize.width,
            height: dialogSize.height
        ))

        styleContainerBackground(container)

        // There is a line above the button
        let yPosition = container.bounds.size.height - kDefaultButtonHeight - kDefaultButtonSpacerHeight
        let lineView = UIView(frame: CGRect(
            x: 0,
            y: yPosition,
            width: container.bounds.size.width,
            height: kDefaultButtonSpacerHeight
        ))

        // The old opaque grey separator was tuned for the removed grey gradient. On glass it
        // reads as a hard bar across the material, so use the system separator, which is
        // translucent and adapts to light/dark.
        lineView.backgroundColor = separatorColor
        container.addSubview(lineView)
        // Title
        self.titleLabel = UILabel(frame: CGRect(x: 25, y: 10, width: 280, height: 30))
        self.titleLabel.textAlignment = .center
        self.titleLabel.textColor = self.textColor
        self.titleLabel.font = self.font.withSize(17)
        container.addSubview(self.titleLabel)

        self.datePicker = configuredDatePicker()
        container.addSubview(self.datePicker)

        // Add the buttons
        addButtonsToView(container: container)

        return container
    }

    fileprivate func configuredDatePicker() -> UIDatePicker {
        let datePicker = UIDatePicker(frame: CGRect(x: 10, y: 30, width: 0, height: 0))
        datePicker.setValue(self.textColor, forKeyPath: "textColor")
        datePicker.autoresizingMask = .flexibleRightMargin
        datePicker.frame.size.width = 300
        datePicker.frame.size.height = 216
        datePicker.locale = Locale.current
        return datePicker
    }

    /// Add buttons to container
    private func addButtonsToView(container: UIView) {
        var buttonWidth = container.bounds.size.width / 2

        var leftButtonFrame = CGRect(
            x: 0,
            y: container.bounds.size.height - kDefaultButtonHeight,
            width: buttonWidth,
            height: kDefaultButtonHeight
        )
        var rightButtonFrame = CGRect(
            x: buttonWidth,
            y: container.bounds.size.height - kDefaultButtonHeight,
            width: buttonWidth,
            height: kDefaultButtonHeight
        )
        if showCancelButton == false {
            buttonWidth = container.bounds.size.width
            leftButtonFrame = CGRect()
            rightButtonFrame = CGRect(
                x: 0,
                y: container.bounds.size.height - kDefaultButtonHeight,
                width: buttonWidth,
                height: kDefaultButtonHeight
            )
        }
        let interfaceLayoutDirection = UIApplication.shared.userInterfaceLayoutDirection
        let isLeftToRightDirection = interfaceLayoutDirection == .leftToRight

        // Both actions share one colour and differ only in weight, which is how a system alert
        // separates its preferred action from the rest. The rows themselves are square and
        // full-bleed — the hairlines are what divide them, so a corner radius here would detach
        // each button from the dividers it is supposed to meet.
        if showCancelButton {
            self.cancelButton = makeButton()
            self.cancelButton.frame = isLeftToRightDirection ? leftButtonFrame : rightButtonFrame
            self.cancelButton.setTitleColor(actionTitleColor, for: .normal)
            self.cancelButton.titleLabel?.font = .systemFont(ofSize: Self.actionFontSize)
            self.cancelButton.addTarget(self, action: .buttonTapped, for: .touchUpInside)
            container.addSubview(self.cancelButton)

            // The divider between the two actions. A system alert with exactly two actions puts
            // them side by side with a hairline between; without it the pair reads as one wide row.
            let divider = UIView(frame: CGRect(
                x: buttonWidth,
                y: container.bounds.size.height - kDefaultButtonHeight,
                width: kDefaultButtonSpacerHeight,
                height: kDefaultButtonHeight
            ))
            divider.backgroundColor = separatorColor
            container.addSubview(divider)
        }

        self.doneButton = makeButton()
        self.doneButton.frame = isLeftToRightDirection ? rightButtonFrame : leftButtonFrame
        self.doneButton.tag = kDoneButtonTag
        self.doneButton.setTitleColor(actionTitleColor, for: .normal)
        // Semibold marks it as the preferred action, the one difference the system draws between
        // two alert actions.
        self.doneButton.titleLabel?.font = .systemFont(ofSize: Self.actionFontSize, weight: .semibold)
        self.doneButton.addTarget(self, action: .buttonTapped, for: .touchUpInside)
        container.addSubview(self.doneButton)
    }

    @objc func buttonTapped(sender: UIButton) {
        if sender.tag == kDoneButtonTag {
            self.callback?(self.datePicker.date)
        } else {
            self.callback?(nil)
        }

        close()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
