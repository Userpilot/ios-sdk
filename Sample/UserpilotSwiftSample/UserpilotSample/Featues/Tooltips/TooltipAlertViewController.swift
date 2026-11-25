//
//  TooltipAlertViewController.swift
//  UserpilotSample
//
//  One screen per tooltip target alert.
//
//  Each screen sets up a target the SDK cannot use for one reason, for a Builder-made
//  tooltip Flow to point at, and offers a fix that makes the tooltip appear. The SDK log
//  names the alert and the `reason` whose issue `mobile_content_error` sends. Once that
//  error is sent the step's fallback closes the tooltip, so a fix after it needs the
//  screen to be opened again.
//
//  The Android sample has the same screens with the same text and layout.
//

import UIKit

/// The tooltip target alerts and search rules, in the order the Tooltips hub lists them.
enum TooltipAlertCase: Int, CaseIterable {
    case notFound
    case notFoundLongScreen
    case ambiguous
    case notVisible
    case overlapped
    case edgesCutOff

    var title: String {
        switch self {
        case .notFound: return "Not Found"
        case .notFoundLongScreen: return "Not Found, Long Screen"
        case .ambiguous: return "Ambiguous"
        case .notVisible: return "Not Visible"
        case .overlapped: return "Overlapped"
        case .edgesCutOff: return "Edges Cut Off"
        }
    }

    /// The `reason` the SDK reports for this alert.
    var reason: String {
        switch self {
        case .notFound, .notFoundLongScreen, .edgesCutOff: return "not_found"
        case .ambiguous: return "ambiguous"
        case .notVisible: return "not_visible"
        case .overlapped: return "overlapped"
        }
    }

    /// What is wrong with the target on this screen.
    var setup: String {
        switch self {
        case .notFound: return "No view on this screen has the target id."
        case .notFoundLongScreen: return "No view has the target id. The alert waits until you scroll to the bottom."
        case .ambiguous: return "Two views share the target id, so the SDK refuses to pick one."
        case .notVisible: return "The target is on screen but fully transparent."
        case .overlapped: return "The target is on screen, but an opaque view covers it."
        case .edgesCutOff: return "The target's middle is clipped by its container, so it is not there yet."
        }
    }

    var fixTitle: String {
        switch self {
        case .notFound, .notFoundLongScreen: return "Add the target"
        case .ambiguous: return "Remove the duplicate"
        case .notVisible: return "Show the target"
        case .overlapped: return "Remove the cover"
        case .edgesCutOff: return "Show its middle"
        }
    }
}

/// One alert's screen: the unusable target and the fix.
final class TooltipAlertViewController: UIViewController {

    /// The id every alert screen's tooltip points at.
    static let targetIdentifier = "alert-target"

    private let alert: TooltipAlertCase
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let targetArea = UIStackView()
    private let statusLabel = UILabel()
    private let fixButton = UIButton(type: .system)

    // Views the fix action changes.
    private weak var duplicateTarget: UIView?
    private weak var transparentTarget: UIView?
    private weak var clippedTarget: UIView?
    private weak var cover: UIView?

    init(alert: TooltipAlertCase) {
        self.alert = alert
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = alert.title
        view.backgroundColor = .systemBackground
        buildHierarchy()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("tooltip alert \(alert.reason)")
    }

    override func viewWillDisappear(_ animated: Bool) {
        // A parked tooltip must not follow the tester to the next screen.
        UserpilotManager.shared.endExperience()
        super.viewWillDisappear(animated)
    }

    // MARK: - Building

    private func buildHierarchy() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
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
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let reasonLabel = UILabel()
        reasonLabel.text = "Expected reason: \(alert.reason)"
        reasonLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        reasonLabel.textColor = AlertStyle.accent
        stack.addArrangedSubview(reasonLabel)
        stack.addArrangedSubview(body(alert.setup))

        configure(fixButton, title: alert.fixTitle, style: .secondary, action: #selector(fixTapped))
        stack.addArrangedSubview(fixButton)
        stack.addArrangedSubview(body("After the fix the tooltip appears. "
            + "Once the alert was sent the tooltip is closed, so open this screen again. "
            + "If it does not appear right away, scroll a little."))

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "The SDK log names the target alert and its reason (\"Tooltip target alert\" lines)."
        stack.addArrangedSubview(statusLabel)

        let section = UILabel()
        section.text = "Target area"
        section.font = .systemFont(ofSize: 20, weight: .bold)
        stack.addArrangedSubview(section)

        targetArea.axis = .vertical
        targetArea.spacing = 12
        stack.addArrangedSubview(targetArea)
        buildTargetArea()
    }

    /// Puts the target in the broken state this alert is about.
    private func buildTargetArea() {
        switch alert {
        case .notFound:
            targetArea.addArrangedSubview(body("There is no target here yet."))
        case .notFoundLongScreen:
            targetArea.addArrangedSubview(body("This screen is long. Scroll to the bottom: the alert is sent only there."))
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: AlertStyle.longScreenDistance).isActive = true
            targetArea.addArrangedSubview(spacer)
            targetArea.addArrangedSubview(body("Bottom of the screen"))
        case .ambiguous:
            targetArea.addArrangedSubview(makeTarget(title: "Target A"))
            let duplicate = makeTarget(title: "Target B (same id)")
            duplicateTarget = duplicate
            targetArea.addArrangedSubview(duplicate)
        case .notVisible:
            let target = makeTarget(title: "Target")
            target.alpha = 0
            transparentTarget = target
            targetArea.addArrangedSubview(slot(containing: [target]))
        case .overlapped:
            let cover = UILabel()
            cover.text = "Opaque cover"
            cover.textAlignment = .center
            cover.textColor = .white
            cover.font = .systemFont(ofSize: 16, weight: .semibold)
            // A plain colour background with square corners: the shape both SDKs treat as a cover.
            cover.backgroundColor = AlertStyle.cover
            self.cover = cover
            // The cover is added after the target, so it is drawn above it.
            targetArea.addArrangedSubview(slot(containing: [makeTarget(title: "Target"), cover]))
        case .edgesCutOff:
            // The slot clips its child: moved up by three quarters, the target's middle is cut off.
            let target = makeTarget(title: "Target")
            target.transform = CGAffineTransform(translationX: 0, y: -AlertStyle.slotHeight * 0.75)
            clippedTarget = target
            let container = slot(containing: [target])
            container.clipsToBounds = true
            targetArea.addArrangedSubview(container)
        }
    }

    // MARK: - Actions

    @objc private func fixTapped() {
        switch alert {
        case .notFound:
            targetArea.addArrangedSubview(makeTarget(title: "Target"))
        case .notFoundLongScreen:
            // At the top of the long screen: scroll back up to see the tooltip.
            targetArea.insertArrangedSubview(makeTarget(title: "Target"), at: 0)
        case .ambiguous:
            duplicateTarget?.removeFromSuperview()
        case .notVisible:
            transparentTarget?.alpha = 1
        case .overlapped:
            cover?.removeFromSuperview()
        case .edgesCutOff:
            // Moved up by a quarter: the top edge stays cut off, the middle shows, and so does the tooltip.
            clippedTarget?.transform = CGAffineTransform(translationX: 0, y: -AlertStyle.slotHeight * 0.25)
        }
        fixButton.isEnabled = false
    }

    // MARK: - Views

    private func body(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    /// The view a tooltip points at. Its accessibility identifier is the selector.
    private func makeTarget(title: String) -> UIButton {
        let target = UIButton(type: .system)
        configure(target, title: title, style: .target, action: nil)
        target.accessibilityIdentifier = Self.targetIdentifier
        return target
    }

    /// A fixed-height slot, so the layout does not depend on the target's state. Later
    /// views are drawn above earlier ones.
    private func slot(containing views: [UIView]) -> UIView {
        let slot = UIView()
        slot.heightAnchor.constraint(equalToConstant: AlertStyle.slotHeight).isActive = true
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            slot.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: slot.topAnchor),
                view.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: slot.trailingAnchor)
            ])
        }
        return slot
    }

    private func configure(_ button: UIButton, title: String, style: AlertStyle.Button, action: Selector?) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = style.background
        configuration.baseForegroundColor = style.foreground
        configuration.background.cornerRadius = AlertStyle.cornerRadius
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 16, weight: .semibold)
            return attributes
        }
        button.configuration = configuration
        if let action { button.addTarget(self, action: action, for: .touchUpInside) }
    }
}

/// Colours and sizes shared with the Android alert screens.
private enum AlertStyle {
    static let accent = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)        // #007AFF
    static let cover = UIColor(red: 1, green: 0.584, blue: 0, alpha: 1)         // #FF9500, fully opaque
    static let cornerRadius: CGFloat = 10
    static let slotHeight: CGFloat = 52
    static let longScreenDistance: CGFloat = 1_200

    enum Button {
        case primary, secondary, target

        var background: UIColor {
            switch self {
            case .primary: return AlertStyle.accent
            case .secondary: return UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1)   // #F2F2F7
            case .target: return UIColor(red: 0.910, green: 0.941, blue: 0.996, alpha: 1)      // #E8F0FE
            }
        }

        var foreground: UIColor {
            self == .primary ? .white : AlertStyle.accent
        }
    }
}
