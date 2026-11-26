//
//  NewsfeedViewController.swift
//  UserpilotSample
//
//  Instagram-style newsfeed for the Tooltips demo app.
//

import UIKit

final class NewsfeedViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let posts: [NewsfeedPost] = [
        NewsfeedPost(
            username: "maya.design",
            caption: "Shipping the new onboarding polish tonight.",
            likes: 248,
            symbolName: "paintpalette.fill",
            tint: .systemPink
        ),
        NewsfeedPost(
            username: "ops.jordan",
            caption: "Morning dashboards looking healthy across regions.",
            likes: 112,
            symbolName: "sunrise.fill",
            tint: .systemOrange
        ),
        NewsfeedPost(
            username: "product.lena",
            caption: "Prototype walkthrough from today's research session.",
            likes: 389,
            symbolName: "laptopcomputer",
            tint: .systemTeal
        ),
        NewsfeedPost(
            username: "growth.sam",
            caption: "Campaign creative test — swipe for results.",
            likes: 97,
            symbolName: "megaphone.fill",
            tint: .systemIndigo
        )
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Newsfeed"
        view.accessibilityIdentifier = "demo-newsfeed-screen"
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("demo newsfeed")
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = SampleAppearance.screenBackground
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(NewsfeedPostCell.self, forCellReuseIdentifier: NewsfeedPostCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 420
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension NewsfeedViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NewsfeedPostCell.reuseID,
            for: indexPath
        ) as? NewsfeedPostCell else {
            return UITableViewCell()
        }
        cell.configure(with: posts[indexPath.row], index: indexPath.row)
        return cell
    }
}

struct NewsfeedPost {
    let username: String
    let caption: String
    let likes: Int
    let symbolName: String
    let tint: UIColor
}

private final class NewsfeedPostCell: UITableViewCell {

    static let reuseID = "NewsfeedPostCell"

    private let card = CardView()
    private let avatarView = UIImageView()
    private let usernameLabel = UILabel()
    private let mediaView = UIImageView()
    private let likeButton = UIButton(type: .system)
    private let commentButton = UIButton(type: .system)
    private let likesLabel = UILabel()
    private let captionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with post: NewsfeedPost, index: Int) {
        usernameLabel.text = post.username
        captionLabel.text = "\(post.username)  \(post.caption)"
        likesLabel.text = "\(post.likes) likes"
        mediaView.image = UIImage(systemName: post.symbolName)
        mediaView.tintColor = post.tint
        avatarView.tintColor = post.tint
        accessibilityIdentifier = "demo-newsfeed-post-\(index)"
        likeButton.accessibilityIdentifier = "demo-newsfeed-like-\(index)"
        commentButton.accessibilityIdentifier = "demo-newsfeed-comment-\(index)"
    }

    private func build() {
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.contentMode = .scaleAspectFit
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        usernameLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let header = UIStackView(arrangedSubviews: [avatarView, usernameLabel, UIView()])
        header.axis = .horizontal
        header.spacing = 10
        header.alignment = .center

        mediaView.contentMode = .scaleAspectFit
        mediaView.backgroundColor = SampleAppearance.screenBackground
        mediaView.layer.cornerRadius = 12
        mediaView.clipsToBounds = true
        mediaView.translatesAutoresizingMaskIntoConstraints = false

        likeButton.setImage(UIImage(systemName: "heart"), for: .normal)
        commentButton.setImage(UIImage(systemName: "bubble.right"), for: .normal)
        likeButton.tintColor = .label
        commentButton.tintColor = .label

        let actions = UIStackView(arrangedSubviews: [likeButton, commentButton, UIView()])
        actions.axis = .horizontal
        actions.spacing = 16

        likesLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        captionLabel.font = .systemFont(ofSize: 14)
        captionLabel.numberOfLines = 0
        captionLabel.textColor = .label

        let stack = UIStackView(arrangedSubviews: [header, mediaView, actions, likesLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),
            mediaView.heightAnchor.constraint(equalToConstant: 220)
        ])
    }
}
