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

// MARK: - MetadataRow

struct MetadataRow {
  let label: String
  let value: String
}

// MARK: - MetadataSection

struct MetadataSection {
  let title: String
  let rows: [MetadataRow]
}

// MARK: - SongMetadataVC

class SongMetadataVC: UIViewController {
  var playable: AbstractPlayable?
  
  private lazy var tableView: UITableView = {
    let table = UITableView(frame: .zero, style: .insetGrouped)
    table.translatesAutoresizingMaskIntoConstraints = false
    table.delegate = self
    table.dataSource = self
    table.register(MetadataCell.self, forCellReuseIdentifier: MetadataCell.identifier)
    return table
  }()
  
  private var sections: [MetadataSection] = []
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .systemBackground
    
    setupNavigationBar()
    setupTableView()
    buildMetadataSections()
  }
  
  private func setupNavigationBar() {
    title = "Song Info"
  }
  
  private func setupTableView() {
    view.addSubview(tableView)
    
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }
  
  private func buildMetadataSections() {
    guard let playable = playable else { return }
    
    var generalRows: [MetadataRow] = []
    var technicalRows: [MetadataRow] = []
    var replayGainRows: [MetadataRow] = []
    var cacheRows: [MetadataRow] = []
    
    // General Information
    generalRows.append(MetadataRow(label: "Title", value: playable.title))
    
    if let song = playable.asSong {
      if let artist = song.artist {
        generalRows.append(MetadataRow(label: "Artist", value: artist.name))
      }
      if let album = song.album {
        generalRows.append(MetadataRow(label: "Album", value: album.name))
      }
      if let genre = song.genre {
        generalRows.append(MetadataRow(label: "Genre", value: genre.name))
      }
    }
    
    if playable.track > 0 {
      generalRows.append(MetadataRow(label: "Track", value: "\(playable.track)"))
    }
    
    if let disk = playable.disk, !disk.isEmpty {
      generalRows.append(MetadataRow(label: "Disc", value: disk))
    }
    
    if playable.year > 0 {
      generalRows.append(MetadataRow(label: "Year", value: "\(playable.year)"))
    }
    
    if playable.duration > 0 {
      generalRows.append(MetadataRow(label: "Duration", value: playable.duration.asDurationString))
    }
    
    if let song = playable.asSong {
      generalRows.append(MetadataRow(label: "Rating", value: song.rating > 0 ? "\(song.rating) / 5" : "Not rated"))
      generalRows.append(MetadataRow(label: "Favorite", value: song.isFavorite ? "Yes" : "No"))
    }
    
    // Technical Information
    if playable.bitrate > 0 {
      let bitrateKbps = (playable.bitrate + 500) / 1000  // Round to nearest kbps
      technicalRows.append(MetadataRow(label: "Bitrate", value: "\(bitrateKbps) kbps"))
    }
    
    if let contentType = playable.contentType {
      technicalRows.append(MetadataRow(label: "Format", value: contentType))
    }
    
    if playable.size > 0 {
      let sizeInMB = Double(playable.size) / (1024 * 1024)
      technicalRows.append(MetadataRow(label: "File Size", value: String(format: "%.2f MB", sizeInMB)))
    }
    
    technicalRows.append(MetadataRow(label: "ID", value: playable.id))
    
    // ReplayGain Information
    if playable.replayGainTrackGain != 0 {
      let sign = playable.replayGainTrackGain >= 0 ? "+" : ""
      replayGainRows.append(MetadataRow(
        label: "Track Gain",
        value: String(format: "%@%.2f dB", sign, playable.replayGainTrackGain)
      ))
    }
    
    if playable.replayGainTrackPeak != 0 {
      replayGainRows.append(MetadataRow(
        label: "Track Peak",
        value: String(format: "%.6f", playable.replayGainTrackPeak)
      ))
    }
    
    if playable.replayGainAlbumGain != 0 {
      let sign = playable.replayGainAlbumGain >= 0 ? "+" : ""
      replayGainRows.append(MetadataRow(
        label: "Album Gain",
        value: String(format: "%@%.2f dB", sign, playable.replayGainAlbumGain)
      ))
    }
    
    if playable.replayGainAlbumPeak != 0 {
      replayGainRows.append(MetadataRow(
        label: "Album Peak",
        value: String(format: "%.6f", playable.replayGainAlbumPeak)
      ))
    }
    
    // Cache Information
    cacheRows.append(MetadataRow(label: "Cached", value: playable.isCached ? "Yes" : "No"))
    
    if playable.isCached, let transcodedType = playable.contentTypeTranscoded {
      cacheRows.append(MetadataRow(label: "Cached Format", value: transcodedType))
    }
    
    // Build sections (only add non-empty sections)
    if !generalRows.isEmpty {
      sections.append(MetadataSection(title: "General", rows: generalRows))
    }
    if !technicalRows.isEmpty {
      sections.append(MetadataSection(title: "Technical", rows: technicalRows))
    }
    if !replayGainRows.isEmpty {
      sections.append(MetadataSection(title: "ReplayGain", rows: replayGainRows))
    }
    if !cacheRows.isEmpty {
      sections.append(MetadataSection(title: "Cache", rows: cacheRows))
    }
  }
}

// MARK: - UITableViewDataSource

extension SongMetadataVC: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    sections.count
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    sections[section].rows.count
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    sections[section].title
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(
      withIdentifier: MetadataCell.identifier,
      for: indexPath
    ) as? MetadataCell else {
      return UITableViewCell()
    }
    
    let row = sections[indexPath.section].rows[indexPath.row]
    cell.configure(label: row.label, value: row.value)
    return cell
  }
}

// MARK: - UITableViewDelegate

extension SongMetadataVC: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    // Copy value to clipboard
    let row = sections[indexPath.section].rows[indexPath.row]
    UIPasteboard.general.string = row.value
    
    // Show brief feedback
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
  }
}

// MARK: - MetadataCell

class MetadataCell: UITableViewCell {
  static let identifier = "MetadataCell"
  
  private let labelLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 15)
    label.textColor = .secondaryLabel
    return label
  }()
  
  private let valueLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 15)
    label.textColor = .label
    label.textAlignment = .right
    label.numberOfLines = 2
    label.lineBreakMode = .byTruncatingMiddle
    return label
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupViews()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupViews() {
    contentView.addSubview(labelLabel)
    contentView.addSubview(valueLabel)
    
    NSLayoutConstraint.activate([
      labelLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      labelLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      labelLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.35),
      
      valueLabel.leadingAnchor.constraint(equalTo: labelLabel.trailingAnchor, constant: 8),
      valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      valueLabel.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 11),
      valueLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -11),
    ])
  }
  
  func configure(label: String, value: String) {
    labelLabel.text = label
    valueLabel.text = value
  }
}
