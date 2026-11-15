//
//  CurrentlyPlayingTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 07.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import AmperfyKit
import MarqueeLabel
import UIKit
import VYPlayIndicator

class CurrentlyPlayingTableCell: BasicTableCell {
  static let rowHeight: CGFloat = 94.0

  private var rootView: PopupPlayerVC?

  @IBOutlet
  weak var artworkImage: LibraryEntityImage!
  @IBOutlet
  weak var titleLabel: MarqueeLabel!
  @IBOutlet
  weak var artistLabel: MarqueeLabel!
  @IBOutlet
  weak var favoriteButton: UIButton!
  @IBOutlet
  weak var optionsButton: UIButton!

  private let playIndicator = PlayIndicator(rootViewTypeName: "PopupPlayerCurrentlyPlaying")
  private let durationLabel = UILabel()
  private let ratingStackView = UIStackView()
  private var ratingStarViews = [UIImageView]()

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  func prepare(toWorkOnRootView: PopupPlayerVC?) {
    rootView = toWorkOnRootView
    titleLabel.applyAmperfyStyle()
    artistLabel.applyAmperfyStyle()
    setupDurationAndRating()
    setupAccentLines()
    refresh()
  }

  /// Accent colored lines above and below the current song
  private func setupAccentLines() {
    for isTop in [true, false] {
      let line = UIView()
      line.backgroundColor = .tintColor
      line.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(line)
      NSLayoutConstraint.activate([
        line.heightAnchor.constraint(equalToConstant: 1),
        line.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
        line.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        isTop ? line.topAnchor.constraint(equalTo: contentView.topAnchor) :
          line.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      ])
    }
  }

  /// Duration above the rating stars on the right, like the queue rows
  private func setupDurationAndRating() {
    durationLabel.font = .systemFont(ofSize: 14)
    durationLabel.textColor = .labelColor
    durationLabel.textAlignment = .right

    ratingStackView.axis = .horizontal
    ratingStackView.spacing = -2 // same tight star spacing as the queue rows
    for _ in 0 ..< 5 {
      let starView = UIImageView(image: .starFill)
      starView.contentMode = .scaleAspectFit
      starView.tintColor = UIColor(red: 0.882, green: 0.686, blue: 0.255, alpha: 1.0) // #e1af41
      starView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        starView.widthAnchor.constraint(equalToConstant: 12),
        starView.heightAnchor.constraint(equalToConstant: 12),
      ])
      ratingStarViews.append(starView)
      ratingStackView.addArrangedSubview(starView)
    }

    let infoStackView = UIStackView(arrangedSubviews: [durationLabel, ratingStackView])
    infoStackView.axis = .vertical
    infoStackView.alignment = .trailing
    infoStackView.spacing = 2
    infoStackView.translatesAutoresizingMaskIntoConstraints = false
    infoStackView.setContentHuggingPriority(.required, for: .horizontal)
    infoStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    contentView.addSubview(infoStackView)
    NSLayoutConstraint.activate([
      infoStackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
      infoStackView.centerYAnchor.constraint(equalTo: artworkImage.centerYAnchor),
    ])

    // The title runs to the right margin in the xib: end it before the duration instead
    if let titleTrailing = contentView.constraints.first(where: {
      $0.firstItem === contentView && $0.firstAttribute == .trailingMargin &&
        $0.secondItem is UIButton && $0.secondItem !== optionsButton
    }), let titleButton = titleTrailing.secondItem as? UIView {
      titleTrailing.isActive = false
      titleButton.trailingAnchor.constraint(equalTo: infoStackView.leadingAnchor, constant: -8)
        .isActive = true
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // The play indicator is sized when added; keep it centered once the artwork has its size
    let bounds = artworkImage.bounds
    for layer in artworkImage.layer.sublayers ?? [] {
      if layer is OverlayLayer {
        layer.frame = bounds
      } else if layer is VYPlayIndicator {
        let size = min(20, bounds.width, bounds.height)
        layer.frame = CGRect(
          x: (bounds.width - size) / 2,
          y: (bounds.height - size) / 2,
          width: size,
          height: size
        )
      }
    }
  }

  func refresh() {
    rootView?.playerHandler?.refreshCurrentlyPlayingInfo(
      artworkImage: artworkImage,
      titleLabel: titleLabel,
      artistLabel: artistLabel
    )
    // Hide buttons - favorite is now in rating view, options is in player controls
    favoriteButton.isHidden = true
    optionsButton.isHidden = true
    refreshPlayStateDurationAndRating()
  }

  private func refreshPlayStateDurationAndRating() {
    guard let playable = appDelegate.player.currentlyPlaying else {
      playIndicator.reset()
      durationLabel.isHidden = true
      ratingStackView.isHidden = true
      return
    }
    // Animated bars while playing, paused bars otherwise
    playIndicator.display(playable: playable, rootView: artworkImage, isOnImage: true)
    setNeedsLayout()

    durationLabel.isHidden = playable.isRadio || !appDelegate.storage.settings.user.isShowSongDuration
    durationLabel.text = playable.duration.asColonDurationString

    let rating = playable.asSong?.rating ?? 0
    for (index, starView) in ratingStarViews.enumerated() {
      starView.isHidden = index >= rating
    }
    ratingStackView.isHidden = rating == 0 || !appDelegate.storage.settings.user.isShowRating
  }

  func refreshArtwork() {
    rootView?.playerHandler?.refreshArtwork(artworkImage: artworkImage)
  }

  @IBAction
  func artworkPressed(_ sender: Any) {
    rootView?.controlView?.displayPlaylistPressed()
  }

  @IBAction
  func titlePressed(_ sender: Any) {
    rootView?.displayAlbumDetail()
    rootView?.displayPodcastDetail()
  }

  @IBAction
  func artistNamePressed(_ sender: Any) {
    rootView?.displayArtistDetail()
    rootView?.displayPodcastDetail()
  }

  @IBAction
  func favoritePressed(_ sender: Any) {
    rootView?.favoritePressed()
    rootView?.refreshFavoriteButton(button: favoriteButton)
  }
}
