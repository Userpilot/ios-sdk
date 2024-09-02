//
//  CarouselCollectionViewCell.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 26/08/2024.
//

import UIKit

class CarouselCollectionViewCell: UICollectionViewCell, CollectionViewCellFromNib {

    let theScrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = .systemYellow
        return view
    }()

    let customerContentView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        return view
    }()

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .fill
        view.spacing = 20
        return view
    }()

    let topLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.boldSystemFont(ofSize: 32.0)
        view.backgroundColor = .yellow
        return view
    }()

    let centerLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.systemFont(ofSize: 17.0)
        view.numberOfLines = 0
        view.backgroundColor = .green
        return view
    }()

    let bottomLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.systemFont(ofSize: 14.0)
        view.numberOfLines = 0
        view.backgroundColor = .cyan
        return view
    }()

    let bottomSpaceVIew: UIView = {
        let view = UIView()
        view.backgroundColor = .blue
        return view
    }()

    // a sample paragraph of text
    let centerSampleText = "Anger is an intense emotion defined as a response" +
    "to a perceived provocation, the invasion of one’s boundaries, or a threat." +
    "From an evolutionary standpoint, anger servers to mobilise psychological" +
    "resources in order to address the threat/invasion. Anger is directed at" +
    "an individual of equal status."

    // update the center-label text when numberOfParagraphs changes
    var numberOfParagraphs = 1 {
        didSet {
            var text = ""
            for index in 1...numberOfParagraphs {
                text += "\(index). " + centerSampleText
                if index < numberOfParagraphs {
                    text += "\n\n"
                }
            }
            centerLabel.text = text
        }
    }

    func bindUI() {
        [theScrollView, contentView, stackView, topLabel, centerLabel, bottomLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(theScrollView)
        theScrollView.addSubview(customerContentView)
        customerContentView.addSubview(stackView)
        stackView.addArrangedSubview(topLabel)
        stackView.addArrangedSubview(centerLabel)
        stackView.addArrangedSubview(bottomLabel)
        // stackView.addArrangedSubview(bottomSpaceVIew)

        let area = contentView.safeAreaLayoutGuide
        let cgarea = theScrollView.contentLayoutGuide
        let fgarea = theScrollView.frameLayoutGuide

        // constrain height of content view to height of scroll view's Frame Layout Guide
        //  with less-than-required Priority so it can get taller when the content gets taller
        let contentViewHeightConstraint = contentView.heightAnchor.constraint(
            equalTo: fgarea.heightAnchor,
            constant: 0.0)
        contentViewHeightConstraint.priority = .defaultLow

        NSLayoutConstraint.activate([
            // constrain scroll view Top to buttons Bottom plus 8-points "spacing"
            //  leading/trailing/bottom to the safe area
            theScrollView.topAnchor.constraint(equalTo: area.topAnchor, constant: 0.0),
            theScrollView.leadingAnchor.constraint(equalTo: area.leadingAnchor, constant: 0.0),
            theScrollView.trailingAnchor.constraint(equalTo: area.trailingAnchor, constant: 0.0),
            theScrollView.bottomAnchor.constraint(equalTo: area.bottomAnchor, constant: 0.0),

            // constrain all 4 sides of the content view to the scroll view's Content Layout Guide
            contentView.topAnchor.constraint(equalTo: cgarea.topAnchor, constant: 0.0),
            contentView.leadingAnchor.constraint(equalTo: cgarea.leadingAnchor, constant: 0.0),
            contentView.trailingAnchor.constraint(equalTo: cgarea.trailingAnchor, constant: 0.0),
            contentView.bottomAnchor.constraint(equalTo: cgarea.bottomAnchor, constant: 0.0),

            // constrain width of content view to width of scroll view's Frame Layout Guide
            contentView.widthAnchor.constraint(equalTo: fgarea.widthAnchor, constant: 0.0),

            // constrain the stack view >= 8-pts from the top
            // <= minus 8-pts from the bottom
            // 40-pts leading and trailing
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8.0),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8.0),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40.0),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40.0),

            // constrain stack view centerY to contentView centerY
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0.0),

            // activate the contentView's height constraint
            contentViewHeightConstraint

        ])

        topLabel.text = "Anger"
        bottomLabel.text = "Based on information from Wikipedia APA Dictionary of Psychology"

        numberOfParagraphs = 1
    }

}
