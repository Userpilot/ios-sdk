//
//  DashboardDetailViewController.swift
//  UserpilotSample
//
//  Expanded metric detail with extra interactive components.
//

import UIKit

final class DashboardDetailViewController: BaseViewController {

    private let metric: DashboardMetric
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(metric: DashboardMetric) {
        self.metric = metric
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = metric.title
        view.accessibilityIdentifier = "demo-dashboard-detail"
        setupLayout()
        buildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("demo dashboard detail")
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 40, right: 16)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    // The demo assembles one static card stack.
    // swiftlint:disable:next function_body_length
    private func buildContent() {
        let hero = UIImageView(image: UIImage(systemName: metric.symbolName))
        hero.contentMode = .scaleAspectFit
        hero.tintColor = SampleAppearance.accentColor
        hero.backgroundColor = SampleAppearance.elevatedBackground
        hero.layer.cornerRadius = SampleAppearance.contentCardCornerRadius
        hero.clipsToBounds = true
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.heightAnchor.constraint(equalToConstant: 160).isActive = true
        hero.accessibilityIdentifier = "demo-detail-hero"
        contentStack.addArrangedSubview(hero)

        let valueLabel = UILabel()
        valueLabel.text = metric.value
        valueLabel.font = .systemFont(ofSize: 36, weight: .bold)
        valueLabel.accessibilityIdentifier = "demo-detail-value"

        let deltaLabel = UILabel()
        deltaLabel.text = "\(metric.delta) vs last week"
        deltaLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        deltaLabel.textColor = metric.delta.hasPrefix("-") ? .systemRed : .systemGreen

        let description = UILabel()
        description.text = "Deep dive into \(metric.title.lowercased()). "
            + "Use the actions below to export, share, or refresh this metric."
        description.numberOfLines = 0
        description.textColor = .secondaryLabel
        description.font = .systemFont(ofSize: 15)

        contentStack.addArrangedSubview(valueLabel)
        contentStack.addArrangedSubview(deltaLabel)
        contentStack.addArrangedSubview(description)

        let chartCard = CardView()
        let chartTitle = UILabel()
        chartTitle.text = "Weekly breakdown"
        chartTitle.font = .systemFont(ofSize: 16, weight: .semibold)

        let chart = SimpleBarChartView()
        chart.values = metric.chartValues
        chart.labels = metric.chartLabels
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 160).isActive = true
        chart.accessibilityIdentifier = "demo-detail-chart"

        let chartStack = UIStackView(arrangedSubviews: [chartTitle, chart])
        chartStack.axis = .vertical
        chartStack.spacing = 12
        chartStack.translatesAutoresizingMaskIntoConstraints = false
        chartStack.isLayoutMarginsRelativeArrangement = true
        chartStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        chartCard.addSubview(chartStack)
        NSLayoutConstraint.activate([
            chartStack.topAnchor.constraint(equalTo: chartCard.topAnchor),
            chartStack.leadingAnchor.constraint(equalTo: chartCard.leadingAnchor),
            chartStack.trailingAnchor.constraint(equalTo: chartCard.trailingAnchor),
            chartStack.bottomAnchor.constraint(equalTo: chartCard.bottomAnchor)
        ])
        contentStack.addArrangedSubview(chartCard)

        let exportButton = UIButton(type: .system)
        exportButton.applyLiquidGlassStyle(.prominent, title: "Export report")
        exportButton.accessibilityIdentifier = "demo-detail-export"
        exportButton.addTarget(self, action: #selector(didTapExport), for: .touchUpInside)

        let shareButton = UIButton(type: .system)
        shareButton.applyLiquidGlassStyle(.regular, title: "Share snapshot")
        shareButton.accessibilityIdentifier = "demo-detail-share"
        shareButton.addTarget(self, action: #selector(didTapShare), for: .touchUpInside)

        let refreshButton = UIButton(type: .system)
        refreshButton.applyLiquidGlassStyle(.regular, title: "Refresh data")
        refreshButton.accessibilityIdentifier = "demo-detail-refresh"
        refreshButton.addTarget(self, action: #selector(didTapRefresh), for: .touchUpInside)

        contentStack.addArrangedSubview(exportButton)
        contentStack.addArrangedSubview(shareButton)
        contentStack.addArrangedSubview(refreshButton)

        let galleryTitle = UILabel()
        galleryTitle.text = "Related visuals"
        galleryTitle.font = .systemFont(ofSize: 18, weight: .bold)
        contentStack.addArrangedSubview(galleryTitle)

        let gallery = UIStackView()
        gallery.axis = .horizontal
        gallery.spacing = 12
        gallery.distribution = .fillEqually
        for symbol in ["photo", "chart.pie.fill", "map.fill"] {
            let imageView = UIImageView(image: UIImage(systemName: symbol))
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = SampleAppearance.accentColor
            imageView.backgroundColor = SampleAppearance.elevatedBackground
            imageView.layer.cornerRadius = 12
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.heightAnchor.constraint(equalToConstant: 88).isActive = true
            gallery.addArrangedSubview(imageView)
        }
        contentStack.addArrangedSubview(gallery)
    }

    @objc private func didTapExport() {
        presentAlert(title: "Export", message: "\(metric.title) report queued.")
    }

    @objc private func didTapShare() {
        presentAlert(title: "Share", message: "Snapshot of \(metric.title) ready to share.")
    }

    @objc private func didTapRefresh() {
        presentAlert(title: "Refresh", message: "Latest \(metric.title) data loaded.")
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
