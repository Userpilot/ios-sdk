//
//  SampleAppearance.swift
//  UserpilotSample
//

import UIKit

enum SampleAppearance {
    static var screenBackground: UIColor { .systemGroupedBackground }
    static var elevatedBackground: UIColor { .secondarySystemGroupedBackground }
    static var accentColor: UIColor { UIColor(named: "AccentColor") ?? .systemBlue }
    static let buttonHeight: CGFloat = 52
    static let contentCardCornerRadius: CGFloat = 16
    static let contentCardInset: CGFloat = 16
}

enum LiquidGlassButtonStyle {
    case prominent
    case regular
}

extension UIButton {

    func applyLiquidGlassStyle(
        _ style: LiquidGlassButtonStyle = .prominent,
        title: String? = nil,
        tintColor: UIColor? = SampleAppearance.accentColor,
        unifiedHeight: Bool = true
    ) {
        let resolvedTitle = title ?? configuration?.title ?? self.title(for: .normal)
        let resolvedImage = configuration?.image ?? image(for: .normal)

        backgroundColor = nil
        layer.borderWidth = 0
        layer.borderColor = nil
        layer.shadowOpacity = 0
        clipsToBounds = false

        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = style == .prominent ? .prominentGlass() : .glass()
        } else if style == .prominent {
            config = .filled()
            config.baseBackgroundColor = tintColor
            config.baseForegroundColor = .white
        } else {
            config = .bordered()
            config.baseForegroundColor = tintColor
            config.background.strokeColor = tintColor
            config.background.strokeWidth = 1
        }

        if let resolvedTitle {
            config.title = resolvedTitle
        }
        if let resolvedImage {
            config.image = resolvedImage
        }
        config.titleAlignment = .center
        config.titleLineBreakMode = .byWordWrapping
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 16, weight: .semibold)
            return outgoing
        }

        configuration = config
        if let tintColor {
            self.tintColor = tintColor
        }
        if unifiedHeight {
            pinToStandardButtonHeight()
        }
    }

    func pinToStandardButtonHeight() {
        let target = SampleAppearance.buttonHeight
        constraints
            .filter { $0.firstAttribute == .height && $0.firstItem as? UIView == self }
            .forEach { $0.constant = target }

        if !constraints.contains(where: { $0.firstAttribute == .height && $0.firstItem as? UIView == self }) {
            heightAnchor.constraint(equalToConstant: target).isActive = true
        }
    }
}

final class LiquidGlassButton: UIButton {

    @IBInspectable var isProminent: Bool = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyLiquidGlassStyle(.prominent)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyLiquidGlassStyle(isProminent ? .prominent : .regular)
    }
}

extension UIViewController {

    /// Wraps the first `UIStackView` inside the screen's primary `UIScrollView`
    /// in a rounded white content card on the grouped background.
    func wrapPrimaryScrollContentInCard() {
        guard
            let scrollView = view.subviews.compactMap({ $0 as? UIScrollView }).first,
            let content = scrollView.subviews.first(where: { $0 is UIStackView })
        else { return }

        let conflicting = (scrollView.constraints + view.constraints).filter { constraint in
            let first = constraint.firstItem as? UIView
            let second = constraint.secondItem as? UIView
            return first == content || second == content
        }
        NSLayoutConstraint.deactivate(conflicting)

        let card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        content.removeFromSuperview()
        scrollView.addSubview(card)
        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        let inset = SampleAppearance.contentCardInset
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor, constant: inset),
            card.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: inset),
            card.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -inset),
            card.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            card.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(inset * 2)),

            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
    }
}
