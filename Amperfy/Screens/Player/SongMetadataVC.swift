//
//  SongMetadataVC.swift
//  Amperfy
//
//  Created for Musify
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
import UIKit

// MARK: - SongMetadataVC

class SongMetadataVC: UIViewController {
  var playable: AbstractPlayable?
  
  private let scrollView = UIScrollView()
  private let stackView = UIStackView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .systemGroupedBackground
    
    setupNavigationBar()
    setupScrollView()
    buildMetadataContent()
  }
  
  private func setupNavigationBar() {
    title = "Song Info"
  }
  
  private func setupScrollView() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.spacing = 0
    scrollView.addSubview(stackView)
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      
      stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
      stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
      stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
      stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
    ])
  }
  
  private func buildMetadataContent() {
    guard let playable = playable else { return }
    
    // General Section
    var generalRows: [(String, String)] = []
    generalRows.append(("Title", playable.title))
    
    if let song = playable.asSong {
      if let artist = song.artist {
        generalRows.append(("Artist", artist.name))
      }
      if let album = song.album {
        generalRows.append(("Album", album.name))
      }
      if let genre = song.genre {
        generalRows.append(("Genre", genre.name))
      }
    }
    
    if playable.track > 0 {
      generalRows.append(("Track", "\(playable.track)"))
    }
    
    if let disk = playable.disk, !disk.isEmpty {
      generalRows.append(("Disc", disk))
    }
    
    if playable.year > 0 {
      generalRows.append(("Year", "\(playable.year)"))
    }
    
    if playable.duration > 0 {
      generalRows.append(("Duration", playable.duration.asDurationString))
    }
    
    if let song = playable.asSong {
      generalRows.append(("Rating", song.rating > 0 ? "\(song.rating) / 5" : "Not rated"))
      generalRows.append(("Favorite", song.isFavorite ? "Yes" : "No"))
    }
    
    addSection(title: "General", rows: generalRows)
    
    // Technical Section
    var technicalRows: [(String, String)] = []
    
    if playable.bitrate > 0 {
      let bitrateKbps = (playable.bitrate + 500) / 1000
      technicalRows.append(("Bitrate", "\(bitrateKbps) kbps"))
    }
    
    if let contentType = playable.contentType {
      technicalRows.append(("Format", contentType))
    }
    
    if playable.size > 0 {
      let sizeInMB = Double(playable.size) / (1024 * 1024)
      technicalRows.append(("File Size", String(format: "%.2f MB", sizeInMB)))
    }
    
    technicalRows.append(("ID", playable.id))
    
    if !technicalRows.isEmpty {
      addSection(title: "Technical", rows: technicalRows)
    }
    
    // ReplayGain Section
    var replayGainRows: [(String, String)] = []
    
    if playable.replayGainTrackGain != 0 {
      let sign = playable.replayGainTrackGain >= 0 ? "+" : ""
      replayGainRows.append(("Track Gain", String(format: "%@%.2f dB", sign, playable.replayGainTrackGain)))
    }
    
    if playable.replayGainTrackPeak != 0 {
      replayGainRows.append(("Track Peak", String(format: "%.6f", playable.replayGainTrackPeak)))
    }
    
    if playable.replayGainAlbumGain != 0 {
      let sign = playable.replayGainAlbumGain >= 0 ? "+" : ""
      replayGainRows.append(("Album Gain", String(format: "%@%.2f dB", sign, playable.replayGainAlbumGain)))
    }
    
    if playable.replayGainAlbumPeak != 0 {
      replayGainRows.append(("Album Peak", String(format: "%.6f", playable.replayGainAlbumPeak)))
    }
    
    if !replayGainRows.isEmpty {
      addSection(title: "ReplayGain", rows: replayGainRows)
    }
    
    // Cache Section
    var cacheRows: [(String, String)] = []
    cacheRows.append(("Cached", playable.isCached ? "Yes" : "No"))
    
    if playable.isCached, let transcodedType = playable.contentTypeTranscoded {
      cacheRows.append(("Cached Format", transcodedType))
    }
    
    addSection(title: "Cache", rows: cacheRows)
  }
  
  private func addSection(title: String, rows: [(String, String)]) {
    // Section header
    let headerLabel = UILabel()
    headerLabel.text = title.uppercased()
    headerLabel.font = .systemFont(ofSize: 13, weight: .regular)
    headerLabel.textColor = .secondaryLabel
    headerLabel.translatesAutoresizingMaskIntoConstraints = false
    
    let headerContainer = UIView()
    headerContainer.translatesAutoresizingMaskIntoConstraints = false
    headerContainer.addSubview(headerLabel)
    
    NSLayoutConstraint.activate([
      headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
      headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
      headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 24),
      headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),
    ])
    
    stackView.addArrangedSubview(headerContainer)
    
    // Section content container with rounded corners
    let sectionContainer = UIView()
    sectionContainer.backgroundColor = .secondarySystemGroupedBackground
    sectionContainer.layer.cornerRadius = 10
    sectionContainer.translatesAutoresizingMaskIntoConstraints = false
    
    let rowsStackView = UIStackView()
    rowsStackView.axis = .vertical
    rowsStackView.spacing = 0
    rowsStackView.translatesAutoresizingMaskIntoConstraints = false
    sectionContainer.addSubview(rowsStackView)
    
    NSLayoutConstraint.activate([
      rowsStackView.topAnchor.constraint(equalTo: sectionContainer.topAnchor),
      rowsStackView.leadingAnchor.constraint(equalTo: sectionContainer.leadingAnchor),
      rowsStackView.trailingAnchor.constraint(equalTo: sectionContainer.trailingAnchor),
      rowsStackView.bottomAnchor.constraint(equalTo: sectionContainer.bottomAnchor),
    ])
    
    for (index, row) in rows.enumerated() {
      let rowView = createRowView(label: row.0, value: row.1, isLast: index == rows.count - 1)
      rowsStackView.addArrangedSubview(rowView)
    }
    
    stackView.addArrangedSubview(sectionContainer)
  }
  
  private func createRowView(label: String, value: String, isLast: Bool) -> UIView {
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false
    
    let labelLabel = UILabel()
    labelLabel.text = label
    labelLabel.font = .systemFont(ofSize: 16)
    labelLabel.textColor = .label
    labelLabel.translatesAutoresizingMaskIntoConstraints = false
    labelLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    
    let valueLabel = UILabel()
    valueLabel.text = value
    valueLabel.font = .systemFont(ofSize: 16)
    valueLabel.textColor = .secondaryLabel
    valueLabel.textAlignment = .right
    valueLabel.numberOfLines = 2
    valueLabel.lineBreakMode = .byTruncatingMiddle
    valueLabel.translatesAutoresizingMaskIntoConstraints = false
    
    container.addSubview(labelLabel)
    container.addSubview(valueLabel)
    
    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.isHidden = isLast
    container.addSubview(separator)
    
    NSLayoutConstraint.activate([
      labelLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      labelLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      
      valueLabel.leadingAnchor.constraint(equalTo: labelLabel.trailingAnchor, constant: 8),
      valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      
      container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
      
      separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: 0.5),
    ])
    
    // Add tap gesture to copy value
    let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
    container.addGestureRecognizer(tap)
    container.isUserInteractionEnabled = true
    container.accessibilityLabel = value
    
    return container
  }
  
  @objc
  private func rowTapped(_ gesture: UITapGestureRecognizer) {
    guard let view = gesture.view, let value = view.accessibilityLabel else { return }
    UIPasteboard.general.string = value
    
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
  }
}
