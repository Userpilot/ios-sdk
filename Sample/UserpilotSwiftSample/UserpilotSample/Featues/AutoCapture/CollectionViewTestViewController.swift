//
//  CollectionViewTestViewController.swift
//  UserpilotSample
//
//  Created by Userpilot on 17/02/2026.
//
//  [Brief Description]
//  Test screen for UICollectionView item selection auto-capture
//

import UIKit

class CollectionViewTestViewController: UIViewController {

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private let cellIdentifier = "CustomCollectionCell"

    private let items = [
        ("📱", "iPhone", "Apple smartphone"),
        ("💻", "MacBook", "Apple laptop"),
        ("⌚", "Watch", "Smart watch"),
        ("🎧", "AirPods", "Wireless earbuds"),
        ("📷", "Camera", "Digital camera"),
        ("🎮", "Console", "Gaming console"),
        ("🖥️", "iMac", "Desktop computer"),
        ("⌨️", "Keyboard", "Mechanical keyboard"),
        ("🖱️", "Mouse", "Wireless mouse"),
        ("🎵", "Music", "Streaming service"),
        ("📺", "TV", "Smart television"),
        ("🔊", "Speaker", "Bluetooth speaker")
    ]

    // MARK: - Lifecycle

    open override var userpilotScreenName: String? {
        "Main Signup Flow"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CollectionView Test"
        view.backgroundColor = .systemBackground
        setupBackButton()
        setupCollectionView()
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.contentHorizontalAlignment = .leading
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    @objc private func backTapped() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        // Calculate item size (2 columns)
        let spacing: CGFloat = 16
        let totalSpacing = spacing * 3 // left + middle + right
        let width = (view.bounds.width - totalSpacing) / 2
        layout.itemSize = CGSize(width: width, height: width + 40)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(CustomCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - UICollectionViewDelegate & DataSource

extension CollectionViewTestViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    // swiftlint:disable:next line_length
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // swiftlint:disable:next line_length
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? CustomCollectionViewCell
        let item = items[indexPath.item]
        cell?.configure(emoji: item.0, title: item.1, subtitle: item.2)
        return cell ?? UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]

        let alert = UIAlertController(
            title: "Item Selected",
            message: "You tapped: \(item.1)\nThis interaction was auto-captured!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        // Deselect after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

// MARK: - Custom CollectionView Cell

class CustomCollectionViewCell: UICollectionViewCell {

    // MARK: - UI Components

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true

        // Emoji
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = .systemFont(ofSize: 48)
        emojiLabel.textAlignment = .center

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        // Subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1

        contentView.addSubview(emojiLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            emojiLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])

        // Add selection style
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
    }

    // MARK: - Configuration

    func configure(emoji: String, title: String, subtitle: String) {
        emojiLabel.text = emoji
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    // MARK: - Selection

    override var isSelected: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                // swiftlint:disable:next line_length
                self.contentView.backgroundColor = self.isSelected ? .systemBlue.withAlphaComponent(0.2) : .secondarySystemBackground
                self.transform = self.isSelected ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
}
