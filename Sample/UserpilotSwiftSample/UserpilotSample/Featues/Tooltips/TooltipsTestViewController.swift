//
//  TooltipsTestViewController.swift
//  UserpilotSample
//
//  Tooltip targets for Builder-made Flows.
//
//  Scrollable content with several targetable views. A Builder-made tooltip
//  Flow points at them by accessibility identifier, and the SDK resolves them
//  the same way it would on any host screen.
//
//  A deliberately useful side effect of the long scroll: the last target starts
//  **below the fold**. A tooltip against it exercises the parked
//  state — the tooltip stays invisible and non-blocking, and appears once you
//  scroll it into view.
//

import UIKit
import Userpilot

final class TooltipsTestViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    /// Shows what the close action asked for and what to expect.
    ///
    /// A tooltip that cannot resolve its target is silent by design — it waits,
    /// invisible, for the target to show up. Why it did not appear is in the
    /// SDK log (enable logging in Configurations).
    private let statusLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Test Bench"
        view.backgroundColor = .systemBackground
        buildHierarchy()

    }

    // MARK: - Building

    private func buildHierarchy() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 40, right: 20)

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        addSection("Targets")
        addBody("Each target's accessibility identifier is the selector a Builder-made tooltip matches.")
        // Every target is rendered exactly once. Two views sharing an identifier
        // are indistinguishable to the selector, which refuses to guess — so a
        // duplicate would make that target permanently unresolvable.
        TooltipTarget.allCases
            .filter { $0 != .belowFold }
            .forEach(addTargetButton)

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Status will appear here."
        stack.addArrangedSubview(statusLabel)

        addCaseButton(title: "Close parked tooltip",
                      detail: "Launch a tooltip at the below-the-fold target first, and do not scroll.",
                      identifier: "close-parked-tooltip", action: #selector(closeParkedTapped))

        addSection("Filler — scroll down")
        addBody("Everything below exists to push the last target off screen, so you "
            + "can test a tooltip that has to wait for you to scroll before it can appear.")
        (1...12).forEach { addBody("Filler row \($0). Keep scrolling.") }

        addSection("Below the fold")
        addBody("This target starts off screen. Launch a tooltip against it, then "
            + "scroll here — it should appear once the target becomes visible.")
        addTargetButton(.belowFold)
    }

    private func addSection(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.numberOfLines = 0
        stack.addArrangedSubview(label)
    }

    private func addBody(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        stack.addArrangedSubview(label)
    }

    /// A view a tooltip can point at.
    ///
    /// The `accessibilityIdentifier` is the whole mechanism — it is what the
    /// selector matches on, scoring 10,000 in the weight table. Nothing
    /// Userpilot-specific is needed on the view itself.
    private func addTargetButton(_ target: TooltipTarget) {
        let button = UIButton(type: .system)
        button.setTitle(target.title, for: .normal)
        button.accessibilityIdentifier = target.identifier
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 10
        var configuration = UIButton.Configuration.plain()
        configuration.title = button.title(for: .normal)
        configuration.baseForegroundColor = button.titleColor(for: .normal)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        button.configuration = configuration

        stack.addArrangedSubview(button)
    }

    private func addCaseButton(title: String, detail: String, identifier: String, action: Selector) {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        var configuration = UIButton.Configuration.plain()
        configuration.title = button.title(for: .normal)
        configuration.baseForegroundColor = button.titleColor(for: .normal)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        button.configuration = configuration
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)

        let description = UILabel()
        description.text = detail
        description.font = .systemFont(ofSize: 13)
        description.textColor = .secondaryLabel
        description.numberOfLines = 0

        container.addArrangedSubview(button)
        container.addArrangedSubview(description)
        stack.addArrangedSubview(container)
    }

    // MARK: - Actions

    @objc private func closeParkedTapped() {
        UserpilotManager.shared.endExperience()
        statusLabel.text = "Close requested. Scroll to the target after removal: the tooltip must not reappear."
    }
}

/// The views on this screen a tooltip can point at.
///
/// `identifier` becomes the view's `accessibilityIdentifier` *and* the
/// selector's `accessibility_identifier` — the two sides of the same match.
private enum TooltipTarget: CaseIterable {
    case saveButton
    case shareButton
    case deleteButton
    case belowFold

    var identifier: String {
        switch self {
        case .saveButton: return "bench-save-button"
        case .shareButton: return "bench-share-button"
        case .deleteButton: return "bench-delete-button"
        case .belowFold: return "bench-below-fold-button"
        }
    }

    var title: String {
        switch self {
        case .saveButton: return "Save"
        case .shareButton: return "Share"
        case .deleteButton: return "Delete"
        case .belowFold: return "Below the fold target"
        }
    }
}
