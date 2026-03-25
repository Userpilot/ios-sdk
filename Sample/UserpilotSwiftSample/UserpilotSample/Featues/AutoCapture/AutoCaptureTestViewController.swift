//
//  AutoCaptureTestViewController.swift
//  UserpilotSample
//
//  Created by Userpilot on 17/02/2026.
//
//  [Brief Description]
//  Test screen for all UIKit auto-capture interaction types
//

import UIKit

class AutoCaptureTestViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    // Controls
    private let switchControl = UISwitch()
    private let slider = UISlider()
    private let segmentedControl = UISegmentedControl(items: ["First", "Second", "Third"])
    private let stepper = UIStepper()
    private let datePicker = UIDatePicker()
    private let pageControl = UIPageControl()
    private let textField = UITextField()
    private let textView = UITextView()

    // Buttons
    private let normalButton = UIButton(type: .system)
    private let tableViewButton = UIButton(type: .system)
    private let collectionViewButton = UIButton(type: .system)
    private let menuButton = UIButton(type: .system)

    // Labels for displaying values
    private let stepperValueLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Auto Capture Test"
        view.backgroundColor = .systemBackground
        setupBackButton()
        setupUI()
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.contentHorizontalAlignment = .leading
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.userpilotRedactText = true
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    @objc private func backTapped() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Setup UI

    private func setupUI() {
        setupScrollView()
        setupStackView()
        addAllControls()
        setupKeyboardDismiss()
    }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    // swiftlint:disable:next function_body_length
    private func addAllControls() {
        // Header
        addSectionHeader("Test All Auto-Capture Interactions")

        // UIButton
        addSectionHeader("1. UIButton (tap)")
        normalButton.setTitle("Tap Me!", for: .normal)
        normalButton.addTarget(self, action: #selector(onNormalButtonTapped), for: .touchUpInside)
        normalButton.backgroundColor = .systemBlue
        normalButton.setTitleColor(.white, for: .normal)
        normalButton.layer.cornerRadius = 8
        normalButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(normalButton)

        // UISwitch
        addSectionHeader("2. UISwitch (switch_changed)")
        let switchContainer = createLabeledControl(label: "Enable Feature", control: switchControl)
        switchControl.addTarget(self, action: #selector(onSwitchChanged), for: .valueChanged)
        stackView.addArrangedSubview(switchContainer)

        // UISlider
        addSectionHeader("3. UISlider (slider_changed)")
        addLabel("Volume: 50%")
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.addTarget(self, action: #selector(onSliderChanged), for: .valueChanged)
        stackView.addArrangedSubview(slider)

        // UISegmentedControl
        addSectionHeader("4. UISegmentedControl (segment_changed)")
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)
        stackView.addArrangedSubview(segmentedControl)

        // UIStepper
        addSectionHeader("5. UIStepper (stepper_changed)")
        // swiftlint:disable:next line_length
        let stepperContainer = createLabeledControl(
            label: "Quantity: ", control: stepper, valueLabel: stepperValueLabel)
        stepper.value = 1
        stepper.minimumValue = 0
        stepper.maximumValue = 10
        stepper.addTarget(self, action: #selector(onStepperChanged), for: .valueChanged)
        stepperValueLabel.text = "1"
        stackView.addArrangedSubview(stepperContainer)

        // UIDatePicker
        addSectionHeader("6. UIDatePicker (date_picker_changed)")
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.addTarget(self, action: #selector(onDatePickerChanged), for: .valueChanged)
        stackView.addArrangedSubview(datePicker)

        // UIPageControl
        addSectionHeader("7. UIPageControl (page_control_changed)")
        pageControl.numberOfPages = 5
        pageControl.currentPage = 0
        pageControl.addTarget(self, action: #selector(onPageControlChanged), for: .valueChanged)
        stackView.addArrangedSubview(pageControl)

        // UITextField
        addSectionHeader("8. UITextField (text_field_end_editing)")
        textField.placeholder = "Enter your name"
        textField.borderStyle = .roundedRect
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stackView.addArrangedSubview(textField)

        // UITextView
        addSectionHeader("9. UITextView (text_view_end_editing)")
        textView.text = "Edit this text..."
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.cornerRadius = 8
        textView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        textView.font = .systemFont(ofSize: 16)
        stackView.addArrangedSubview(textView)

        // TableView Button
        addSectionHeader("10. UITableView Cell Selection")
        tableViewButton.setTitle("Open TableView Test", for: .normal)
        tableViewButton.addTarget(
            self, action: #selector(onTableViewButtonTapped), for: .touchUpInside)
        tableViewButton.backgroundColor = .systemGreen
        tableViewButton.setTitleColor(.white, for: .normal)
        tableViewButton.layer.cornerRadius = 8
        tableViewButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(tableViewButton)

        // CollectionView Button
        addSectionHeader("11. UICollectionView Item Selection")
        collectionViewButton.setTitle("Open CollectionView Test", for: .normal)
        collectionViewButton.addTarget(
            self, action: #selector(onCollectionViewButtonTapped), for: .touchUpInside)
        collectionViewButton.backgroundColor = .systemOrange
        collectionViewButton.setTitleColor(.white, for: .normal)
        collectionViewButton.layer.cornerRadius = 8
        collectionViewButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(collectionViewButton)

        // UIMenu Button
        addSectionHeader("12. UIMenu (menu item tap)")
        setupMenuButton()
        stackView.addArrangedSubview(menuButton)
    }

    private func setupMenuButton() {
        menuButton.setTitle("Show Menu ▼", for: .normal)
        menuButton.backgroundColor = .systemPurple
        menuButton.setTitleColor(.white, for: .normal)
        menuButton.layer.cornerRadius = 8
        menuButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let menuItems = UIMenu(
            title: "Options",
            identifier: UIMenu.Identifier("autocapture_options_menu"),
            options: .displayInline,
            children: [
                UIAction(
                    title: "Option A",
                    identifier: UIAction.Identifier("optionA")
                ) { [weak self] _ in
                    self?.showAlert("Menu", "Option A selected – check autocapture event")
                },
                UIAction(
                    title: "Option B",
                    identifier: UIAction.Identifier("optionB")
                ) { [weak self] _ in
                    self?.showAlert("Menu", "Option B selected – check autocapture event")
                },
                UIAction(
                    title: "Option C",
                    identifier: UIAction.Identifier("optionC")
                ) { [weak self] _ in
                    self?.showAlert("Menu", "Option C selected – check autocapture event")
                },
            ]
        )
        menuButton.menu = menuItems
        menuButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Helper Methods

    private func addSectionHeader(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 16)
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    private func addLabel(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        stackView.addArrangedSubview(label)
    }

    private func createLabeledControl(
        label text: String, control: UIView, valueLabel: UILabel? = nil
    ) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(control)

        var constraints = [
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 44),
        ]

        if let valueLabel = valueLabel {
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.font = .systemFont(ofSize: 14)
            container.addSubview(valueLabel)
            constraints.append(contentsOf: [
                valueLabel.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
                valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
        }

        NSLayoutConstraint.activate(constraints)
        return container
    }

    // MARK: - Actions

    @IBAction func onNormalButtonTapped(_ sender: UIButton) {
        showAlert("Button Tapped", "Normal button interaction captured")
    }

    @IBAction func onSwitchChanged(_ sender: UISwitch) {
        print("Switch value: \(sender.isOn)")
    }

    @IBAction func onSliderChanged(_ sender: UISlider) {
        print("Slider value: \(sender.value)")
    }

    @IBAction func onSegmentChanged(_ sender: UISegmentedControl) {
        print("Segment index: \(sender.selectedSegmentIndex)")
    }

    @IBAction func onStepperChanged(_ sender: UIStepper) {
        stepperValueLabel.text = "\(Int(sender.value))"
        print("Stepper value: \(sender.value)")
    }

    @IBAction func onDatePickerChanged(_ sender: UIDatePicker) {
        print("Date: \(sender.date)")
    }

    @IBAction func onPageControlChanged(_ sender: UIPageControl) {
        print("Page: \(sender.currentPage)")
    }

    @IBAction func onTableViewButtonTapped(_ sender: UIButton) {
        let tableVC = TableViewTestViewController()
        navigationController?.pushViewController(tableVC, animated: true)
    }

    @IBAction func onCollectionViewButtonTapped(_ sender: UIButton) {
        let collectionVC = CollectionViewTestViewController()
        navigationController?.pushViewController(collectionVC, animated: true)
    }

    // MARK: - Text Config Demo Button

    private let textConfigDemoButton = UIButton(type: .system)

    @IBAction func onTextConfigDemoButtonTapped(_ sender: UIButton) {
        let textConfigVC = TextConfigDemoViewController()
        navigationController?.pushViewController(textConfigVC, animated: true)
    }

    // MARK: - Update addAllControls to include the new button

    private func addAllControls() {
        // ... existing code ...

        // UIMenu Button
        addSectionHeader("12. UIMenu (menu item tap)")
        setupMenuButton()
        stackView.addArrangedSubview(menuButton)

        // Text Config Demo Button
        addSectionHeader("13. Text Config Demo")
        textConfigDemoButton.setTitle("Open Text Config Demo", for: .normal)
        textConfigDemoButton.addTarget(
            self, action: #selector(onTextConfigDemoButtonTapped), for: .touchUpInside)
        textConfigDemoButton.backgroundColor = .systemIndigo
        textConfigDemoButton.setTitleColor(.white, for: .normal)
        textConfigDemoButton.layer.cornerRadius = 8
        textConfigDemoButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(textConfigDemoButton)
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
