//
//  MissingSongMetadataSyncer.swift
//  AmperfyKit
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

import AVFoundation
import CoreData
import Foundation
import os.log

// MARK: - SongFileTags

/// Title, artist, album and length read from a downloaded file
public struct SongFileTags: Sendable {
  public var title: String?
  public var artist: String?
  public var album: String?
  public var duration: Double

  public init(title: String?, artist: String?, album: String?, duration: Double) {
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
  }

  static func read(from fileURL: URL) async -> SongFileTags? {
    // AVFoundation does not read the Vorbis comments of FLAC files
    if fileURL.pathExtension.lowercased() == "flac" {
      return (try? Data(contentsOf: fileURL, options: .mappedIfSafe)).flatMap { readFlac(data: $0) }
    }
    let asset = AVURLAsset(url: fileURL)
    guard let items = try? await asset.load(.commonMetadata) else { return nil }
    var tags = SongFileTags(title: nil, artist: nil, album: nil, duration: 0)
    for item in items {
      guard let value = try? await item.load(.stringValue) else { continue }
      switch item.commonKey {
      case .commonKeyTitle: tags.title = value
      case .commonKeyArtist: tags.artist = value
      case .commonKeyAlbumName: tags.album = value
      default: break
      }
    }
    if let duration = try? await asset.load(.duration), duration.isNumeric {
      tags.duration = duration.seconds
    }
    return tags
  }

  /// Reads the STREAMINFO (length) and VORBIS_COMMENT (tags) metadata blocks of a FLAC file
  static func readFlac(data: Data) -> SongFileTags? {
    let bytes = [UInt8](data.prefix(4 * 1024 * 1024)) // metadata blocks come first
    guard bytes.count > 8, bytes[0 ..< 4] == [0x66, 0x4C, 0x61, 0x43] else { return nil } // "fLaC"
    var tags = SongFileTags(title: nil, artist: nil, album: nil, duration: 0)
    var offset = 4
    var isLast = false
    while !isLast, offset + 4 <= bytes.count {
      isLast = bytes[offset] & 0x80 != 0
      let type = bytes[offset] & 0x7F
      let length = Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
      let start = offset + 4
      guard start + length <= bytes.count else { break }
      let block = Array(bytes[start ..< start + length])
      if type == 0, block.count >= 18 { // STREAMINFO
        let sampleRate = Int(block[10]) << 12 | Int(block[11]) << 4 | Int(block[12]) >> 4
        let totalSamples = Int(block[13] & 0x0F) << 32 | Int(block[14]) << 24 |
          Int(block[15]) << 16 | Int(block[16]) << 8 | Int(block[17])
        if sampleRate > 0 { tags.duration = Double(totalSamples) / Double(sampleRate) }
      } else if type == 4 { // VORBIS_COMMENT, little-endian lengths
        func uint32(at index: Int) -> Int? {
          guard index + 4 <= block.count else { return nil }
          return Int(block[index]) | Int(block[index + 1]) << 8 | Int(block[index + 2]) << 16 |
            Int(block[index + 3]) << 24
        }
        guard let vendorLength = uint32(at: 0), let count = uint32(at: 4 + vendorLength)
        else { break }
        var index = 8 + vendorLength
        for _ in 0 ..< count {
          guard let commentLength = uint32(at: index),
                index + 4 + commentLength <= block.count else { break }
          let comment = String(decoding: block[index + 4 ..< index + 4 + commentLength], as: UTF8.self)
          index += 4 + commentLength
          guard let separator = comment.firstIndex(of: "=") else { continue }
          let value = String(comment[comment.index(after: separator)...])
          switch comment[..<separator].uppercased() {
          case "TITLE": tags.title = tags.title ?? value
          case "ARTIST": tags.artist = tags.artist ?? value
          case "ALBUM": tags.album = tags.album ?? value
          default: break
          }
        }
      }
      offset = start + length
    }
    return tags
  }
}

// MARK: - MissingSongMetadataSyncer

/// Songs known only by id ("Unknown Title"): after a library resync, downloaded songs are
/// re-created from their files with only an id. When the server has given its songs new ids
/// (e.g. after a rescan), the old ids are no longer known and their details can not be fetched.
///
/// 1. A downloaded file is matched by its tags to the same song under its new id: the file is
///    moved over to that song, or deleted if that song is already downloaded.
/// 2. The details of the remaining songs are fetched from the server (ids that are still valid).
/// 3. Entries the server does not know and that match nothing (dead downloads and empty entries)
///    are removed with their files, unless they are in a queue or playlist.
@MainActor
public class MissingSongMetadataSyncer {
  private let log = OSLog(subsystem: "Amperfy", category: "MissingSongMetadataSyncer")
  private let account: Account
  private let storage: PersistentStorage
  private let librarySyncer: LibrarySyncer
  private let networkMonitor: NetworkMonitorFacade
  private let eventLogger: EventLogger?
  private let fileManager = CacheFileManager.shared
  /// Reads the tags of a downloaded file; replaceable in tests
  var readTags: (URL) async -> SongFileTags? = { await SongFileTags.read(from: $0) }
  private var isStopped = false
  private var isActive = false

  init(
    account: Account,
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    networkMonitor: NetworkMonitorFacade,
    eventLogger: EventLogger? = nil
  ) {
    self.account = account
    self.storage = storage
    self.librarySyncer = librarySyncer
    self.networkMonitor = networkMonitor
    self.eventLogger = eventLogger
  }

  public func start() {
    isStopped = false
    guard !isActive else { return }
    isActive = true
    Task { @MainActor in
      await self.repairSongsWithoutMetadata()
      self.isActive = false
    }
  }

  public func stop() {
    isStopped = true
  }

  public struct Result: Equatable, Sendable {
    public var movedFiles = 0
    public var deletedDuplicateFiles = 0
    public var fetched = 0
    public var removedLeftovers = 0
    public var deletedDeadDownloads = 0
    public var remaining = 0
  }

  @discardableResult
  func repairSongsWithoutMetadata() async -> Result {
    var result = Result()
    let library = storage.main.library
    let songs = library.getSongsWithoutMetadata(for: account)
    guard !songs.isEmpty else { return result }
    logEvent("Repairing \(songs.count) songs without details")

    // 1. match downloaded files by their tags
    var unmatched = [Song]()
    for song in songs {
      guard !isStopped else { return result }
      if let match = await findMatch(forDownloaded: song) {
        if library.replaceOrphanedSong(song, with: match) {
          result.movedFiles += 1
        } else {
          result.deletedDuplicateFiles += 1
        }
        if (result.movedFiles + result.deletedDuplicateFiles) % 100 == 0 {
          library.saveContext()
        }
      } else {
        unmatched.append(song)
      }
    }
    library.saveContext()

    // 2. fetch details of ids the server still knows
    var unknownToServer = [Song]()
    for song in unmatched {
      guard !isStopped else { return result }
      guard storage.settings.user.isOnlineMode, networkMonitor.isConnectedToNetwork else {
        result.remaining = unmatched.count - result.fetched
        logSummary(result)
        return result // the rest is done on the next start
      }
      try? await librarySyncer.sync(song: song)
      // the sync saved in a background context: read the stored values
      song.managedObject.managedObjectContext?.refresh(song.managedObject, mergeChanges: true)
      if song.managedObject.title != nil {
        result.fetched += 1
      } else {
        unknownToServer.append(song)
      }
    }

    // 3. remove what the server does not know and matches nothing
    for song in unknownToServer {
      guard song.managedObject.playlistItems.isEmpty else {
        result.remaining += 1 // keep queue and playlist entries intact
        continue
      }
      if song.isCached {
        result.deletedDeadDownloads += 1
      } else {
        result.removedLeftovers += 1
      }
      library.deleteOrphanedSong(song)
    }
    library.saveContext()
    logSummary(result)
    return result
  }

  /// The same song under its new id: same title, album (if tagged) and length (±5 s)
  private func findMatch(forDownloaded song: Song) async -> Song? {
    guard let relFilePath = song.relFilePath,
          let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath),
          FileManager.default.fileExists(atPath: absFilePath.path),
          let tags = await readTags(absFilePath),
          let title = tags.title, !title.trimmingCharacters(in: .whitespaces).isEmpty
    else { return nil }

    // titles may end in a space on the server too: try the tag as is, then trimmed
    var titleMatches = storage.main.library.getSongs(for: account, title: title)
    let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
    if titleMatches.isEmpty, trimmedTitle != title {
      titleMatches = storage.main.library.getSongs(for: account, title: trimmedTitle)
    }
    let candidates = titleMatches.filter { candidate in
      guard candidate.managedObject != song.managedObject else { return false }
      if let album = tags.album, !Self.isSame(album, candidate.album?.name) { return false }
      if tags.album == nil, let artist = tags.artist,
         !Self.isSame(artist, candidate.creatorName) { return false }
      if tags.duration > 0, candidate.duration > 0,
         abs(Double(candidate.duration) - tags.duration) > 5 { return false }
      return true
    }
    // prefer the same artist, then a song that is already downloaded
    return candidates.max { lhs, rhs in
      Self.matchScore(lhs, tags: tags) < Self.matchScore(rhs, tags: tags)
    }
  }

  private static func matchScore(_ song: Song, tags: SongFileTags) -> Int {
    var score = 0
    if let artist = tags.artist, isSame(artist, song.creatorName) { score += 2 }
    if song.isCached { score += 1 }
    return score
  }

  private static func isSame(_ lhs: String, _ rhs: String?) -> Bool {
    guard let rhs else { return false }
    return lhs.trimmingCharacters(in: .whitespaces)
      .compare(
        rhs.trimmingCharacters(in: .whitespaces),
        options: [.caseInsensitive, .diacriticInsensitive]
      ) == .orderedSame
  }

  private func logSummary(_ result: Result) {
    logEvent(
      "Moved \(result.movedFiles) downloads to their new song id, " +
        "deleted \(result.deletedDuplicateFiles) duplicate downloads, " +
        "fetched details of \(result.fetched) songs, " +
        "deleted \(result.deletedDeadDownloads) downloads no longer on the server, " +
        "removed \(result.removedLeftovers) empty entries, \(result.remaining) left unmatched"
    )
  }

  private func logEvent(_ message: String) {
    os_log("%s", log: log, type: .info, message)
    eventLogger?.debug(topic: "Missing Song Details", message: message)
  }
}
