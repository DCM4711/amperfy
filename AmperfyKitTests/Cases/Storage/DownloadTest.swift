//
//  DownloadTest.swift
//  AmperfyKitTests
//
//  Created by butterfly-zebra on 13.10.26.
//  Copyright (c) 2026 butterfly-zebra. All rights reserved.
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

@testable import AmperfyKit
import XCTest

@MainActor
class DownloadTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var account2: Account!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    account2 = library.getAccount(info: TestAccountInfo.create2())
  }

  override func tearDown() {}

  private func createUncachedSong(id: String, account: Account) -> Song {
    let song = library.createSong(account: account)
    song.id = id
    song.size = 1000
    song.album = library.getAlbum(
      for: account,
      id: cdHelper.seeder.albums[0].id,
      isDetailFaultResolution: false
    )
    return song
  }

  @discardableResult
  private func createDownload(for song: Song, account: Account) -> Download {
    let download = library.createDownload(account: account, id: song.uniqueID)
    download.element = song
    return download
  }

  func testCompleteLibraryDownloadRequestsStaleDownloadsAgain() {
    _ = createUncachedSong(id: "noDownload", account: account)
    let pending = createUncachedSong(id: "pending", account: account)
    createDownload(for: pending, account: account)
    let finished = createUncachedSong(id: "finished", account: account)
    createDownload(for: finished, account: account).finishDate = Date()
    let failed = createUncachedSong(id: "failed", account: account)
    createDownload(for: failed, account: account).error = .fetchFailed
    let canceled = createUncachedSong(id: "canceled", account: account)
    createDownload(for: canceled, account: account).isCanceled = true
    let cached = createUncachedSong(id: "cached", account: account)
    cached.relFilePath = URL(string: "cached.mp3")
    createDownload(for: cached, account: account).finishDate = Date()
    library.saveContext()

    let songIds = Set(
      library.getSongsForCompleteLibraryDownload(for: account).map { $0.id }
    )
    XCTAssertTrue(songIds.contains("noDownload"))
    XCTAssertFalse(songIds.contains("pending"))
    XCTAssertTrue(songIds.contains("finished"))
    XCTAssertTrue(songIds.contains("failed"))
    XCTAssertTrue(songIds.contains("canceled"))
    XCTAssertFalse(songIds.contains("cached"))
  }

  func testClearFinishedDownloadsKeepsPendingDownloads() async {
    let pendingSong = createUncachedSong(id: "pending", account: account)
    let pending = createDownload(for: pendingSong, account: account)
    let finishedSong = createUncachedSong(id: "finished", account: account)
    let finished = createDownload(for: finishedSong, account: account)
    finished.finishDate = Date()
    let failedSong = createUncachedSong(id: "failed", account: account)
    let failed = createDownload(for: failedSong, account: account)
    failed.error = .fetchFailed
    let otherAccountSong = createUncachedSong(id: "otherAccount", account: account2)
    let otherAccountFinished = createDownload(for: otherAccountSong, account: account2)
    otherAccountFinished.finishDate = Date()
    library.saveContext()

    let requestManager = DownloadRequestManager(
      accountObjectId: account.managedObject.objectID,
      storage: AsyncCoreDataAccessWrapper(persistentContainer: cdHelper.persistentContainer),
      getDownloadDelegateCB: { MOCK_DownloadManagerDelegate() }
    )
    await requestManager.clearFinishedDownloads()

    XCTAssertNotNil(library.getDownload(account: account, id: pending.id))
    XCTAssertNil(library.getDownload(account: account, id: finished.id))
    XCTAssertNil(library.getDownload(account: account, id: failed.id))
    XCTAssertNotNil(library.getDownload(account: account2, id: otherAccountFinished.id))
  }

  func testDeleteCacheRemovesDownloadRecords() {
    let cached = createUncachedSong(id: "cached", account: account)
    cached.relFilePath = URL(string: "cached.mp3")
    let download = createDownload(for: cached, account: account)
    download.finishDate = Date()
    let otherAccountCached = createUncachedSong(id: "otherAccount", account: account2)
    otherAccountCached.relFilePath = URL(string: "otherAccount.mp3")
    let otherAccountDownload = createDownload(for: otherAccountCached, account: account2)
    otherAccountDownload.finishDate = Date()
    library.saveContext()

    library.deletePlayableCachePaths(for: account)
    library.saveContext()

    XCTAssertFalse(cached.isCached)
    XCTAssertNil(library.getDownload(account: account, id: download.id))
    XCTAssertNotNil(library.getDownload(account: account2, id: otherAccountDownload.id))
  }
}

// MARK: - MissingSongMetadataSyncerTest

@MainActor
class MissingSongMetadataSyncerTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var storage: PersistentStorage!
  var account: Account!
  var account2: Account!
  var librarySyncer: MOCK_LibrarySyncer!
  var savedOfflineMode = false
  let fileManager = CacheFileManager.shared
  /// Tags of the test files, by file name without extension (the old song id)
  var tagsByFileId = [String: SongFileTags]()
  var createdFiles = [URL]()

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    storage = PersistentStorage(
      coreDataManager: MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    )
    account = library.getAccount(info: TestAccountInfo.create1())
    account2 = library.getAccount(info: TestAccountInfo.create2())
    librarySyncer = MOCK_LibrarySyncer()
    savedOfflineMode = storage.settings.user.isOfflineMode
    storage.settings.user.isOfflineMode = false
  }

  override func tearDown() async throws {
    storage.settings.user.isOfflineMode = savedOfflineMode
    for file in createdFiles {
      try? FileManager.default.removeItem(at: file)
    }
  }

  /// Like the songs re-created from cached files after a library resync: id only
  @discardableResult
  private func createSongWithoutMetadata(id: String, account: Account) -> Song {
    let song = library.createSong(account: account)
    song.id = id
    return song
  }

  /// Writes a downloaded file for the song and returns its absolute path
  @discardableResult
  private func createDownloadedFile(for song: Song) throws -> URL {
    song.contentTypeTranscoded = "audio/mpeg"
    let relFilePath = try XCTUnwrap(fileManager.createRelPath(for: song))
    let absFilePath = try XCTUnwrap(fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath))
    try FileManager.default.createDirectory(
      at: absFilePath.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("audio of \(song.id)".utf8).write(to: absFilePath)
    createdFiles.append(absFilePath)
    song.relFilePath = relFilePath
    return absFilePath
  }

  /// A song with details under its new id
  private func createSong(id: String, title: String, album albumName: String, duration: Int) -> Song {
    let song = library.createSong(account: account)
    song.id = id
    song.title = title
    let album = library.createAlbum(account: account)
    album.id = "album-\(id)"
    album.name = albumName
    song.album = album
    song.managedObject.combinedDuration = Int16(duration)
    return song
  }

  private func createSyncer() -> MissingSongMetadataSyncer {
    let syncer = MissingSongMetadataSyncer(
      account: account,
      storage: storage,
      librarySyncer: librarySyncer,
      networkMonitor: MOCK_NetworkMonitor()
    )
    syncer.readTags = { [tagsByFileId] url in
      tagsByFileId[url.deletingPathExtension().lastPathComponent]
    }
    return syncer
  }

  func testGetSongsWithoutMetadata_OnlyIdOnlySongsOfAccount() {
    createSongWithoutMetadata(id: "noMeta", account: account)
    createSongWithoutMetadata(id: "otherAccount", account: account2)
    let withTitle = createSongWithoutMetadata(id: "withTitle", account: account)
    withTitle.title = "A Title"
    library.saveContext()

    let ids = Set(storage.main.library.getSongsWithoutMetadata(for: account).map { $0.id })
    XCTAssertTrue(ids.contains("noMeta"))
    XCTAssertFalse(ids.contains("otherAccount"))
    XCTAssertFalse(ids.contains("withTitle"))
  }

  func testRepair_MovesDownloadToSongWithNewId() async throws {
    let orphan = createSongWithoutMetadata(id: "oldId", account: account)
    let oldFile = try createDownloadedFile(for: orphan)
    let newSong = createSong(id: "newId", title: "Sad Lisa", album: "Olte Hodan Mix", duration: 222)
    // a song with the same title on another album must not be picked
    createSong(id: "otherAlbum", title: "Sad Lisa", album: "Tea For The Tillerman", duration: 222)
    tagsByFileId["oldId"] = SongFileTags(
      title: "Sad Lisa", artist: "Cat Stevens", album: "Olte Hodan Mix", duration: 222.4
    )
    library.saveContext()

    let result = await createSyncer().repairSongsWithoutMetadata()

    XCTAssertEqual(result.movedFiles, 1)
    XCTAssertTrue(newSong.isCached)
    let newFile = try XCTUnwrap(fileManager.getAbsoluteAmperfyPath(relFilePath: newSong.relFilePath!))
    createdFiles.append(newFile)
    XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
    XCTAssertTrue(storage.main.library.getSongsWithoutMetadata(for: account).isEmpty)
  }

  func testRepair_DeletesDownloadAlreadyDownloadedUnderNewId() async throws {
    let orphan = createSongWithoutMetadata(id: "oldId", account: account)
    let oldFile = try createDownloadedFile(for: orphan)
    let newSong = createSong(
      id: "newId", title: "Another One Bites The Dust", album: "Greatest Hits I", duration: 215
    )
    let newFile = try createDownloadedFile(for: newSong)
    tagsByFileId["oldId"] = SongFileTags(
      title: "Another One Bites The Dust", artist: "Queen", album: "Greatest Hits I",
      duration: 215.4
    )
    library.saveContext()

    let result = await createSyncer().repairSongsWithoutMetadata()

    XCTAssertEqual(result.deletedDuplicateFiles, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
    XCTAssertTrue(storage.main.library.getSongsWithoutMetadata(for: account).isEmpty)
  }

  func testRepair_DeletesDownloadUnknownToServerWithoutMatch() async throws {
    let orphan = createSongWithoutMetadata(id: "oldId", account: account)
    let oldFile = try createDownloadedFile(for: orphan)
    // only a remastered album is left on the server
    createSong(id: "newId", title: "Sultans Of Swing", album: "Dire Straits (Remastered)", duration: 348)
    tagsByFileId["oldId"] = SongFileTags(
      title: "Sultans Of Swing", artist: "Dire Straits", album: "Dire Straits", duration: 348
    )
    library.saveContext()

    let result = await createSyncer().repairSongsWithoutMetadata()

    XCTAssertEqual(result.movedFiles + result.deletedDuplicateFiles, 0)
    XCTAssertEqual(result.deletedDeadDownloads, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
    XCTAssertTrue(storage.main.library.getSongsWithoutMetadata(for: account).isEmpty)
  }

  func testRepair_KeepsUnmatchedDownloadInQueueOrPlaylist() async throws {
    let orphan = createSongWithoutMetadata(id: "oldId", account: account)
    let oldFile = try createDownloadedFile(for: orphan)
    let playlist = library.createPlaylist(account: account)
    playlist.append(playable: orphan)
    library.saveContext()

    let result = await createSyncer().repairSongsWithoutMetadata()

    XCTAssertEqual(result.deletedDeadDownloads, 0)
    XCTAssertEqual(result.remaining, 1)
    XCTAssertTrue(FileManager.default.fileExists(atPath: oldFile.path))
  }

  func testReadFlacTags() {
    func block(type: UInt8, isLast: Bool, _ content: [UInt8]) -> [UInt8] {
      let length = content.count
      return [(isLast ? 0x80 : 0) | type, UInt8(length >> 16), UInt8((length >> 8) & 0xFF),
              UInt8(length & 0xFF)] + content
    }
    func le32(_ value: Int) -> [UInt8] {
      [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF),
       UInt8((value >> 24) & 0xFF)]
    }
    // STREAMINFO: 44100 Hz, 44100 * 413 samples
    var streamInfo = [UInt8](repeating: 0, count: 34)
    let sampleRate = 44100
    let totalSamples = 44100 * 413
    streamInfo[10] = UInt8(sampleRate >> 12)
    streamInfo[11] = UInt8((sampleRate >> 4) & 0xFF)
    streamInfo[12] = UInt8((sampleRate & 0x0F) << 4)
    streamInfo[14] = UInt8((totalSamples >> 24) & 0xFF)
    streamInfo[15] = UInt8((totalSamples >> 16) & 0xFF)
    streamInfo[16] = UInt8((totalSamples >> 8) & 0xFF)
    streamInfo[17] = UInt8(totalSamples & 0xFF)
    let comments = ["TITLE=From Little Things Big Things Grow", "artist=Paul Kelly", "ALBUM=Songs"]
    var vorbis = le32(6) + Array("vendor".utf8) + le32(comments.count)
    for comment in comments {
      vorbis += le32(comment.utf8.count) + Array(comment.utf8)
    }
    let data = Data(
      Array("fLaC".utf8) + block(type: 0, isLast: false, streamInfo) +
        block(type: 4, isLast: true, vorbis)
    )

    let tags = SongFileTags.readFlac(data: data)

    XCTAssertEqual(tags?.title, "From Little Things Big Things Grow")
    XCTAssertEqual(tags?.artist, "Paul Kelly")
    XCTAssertEqual(tags?.album, "Songs")
    XCTAssertEqual(tags?.duration ?? 0, 413, accuracy: 0.01)
  }

  func testRepair_MatchesTitleEndingInSpace() async throws {
    let orphan = createSongWithoutMetadata(id: "oldId", account: account)
    try createDownloadedFile(for: orphan)
    let newSong = createSong(id: "newId", title: "Clubbed To Death ", album: "Clubbed To Death", duration: 507)
    tagsByFileId["oldId"] = SongFileTags(
      title: "Clubbed To Death ", artist: "Rob Dougan", album: "Clubbed To Death", duration: 507.2
    )
    library.saveContext()

    let result = await createSyncer().repairSongsWithoutMetadata()

    XCTAssertEqual(result.movedFiles, 1)
    XCTAssertTrue(newSong.isCached)
    if let relFilePath = newSong.relFilePath,
       let newFile = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
      createdFiles.append(newFile)
    }
  }

  func testRepair_FetchesValidIdsAndRemovesEmptyLeftovers() async {
    createSongWithoutMetadata(id: "valid", account: account)
    createSongWithoutMetadata(id: "gone", account: account)
    library.saveContext()
    librarySyncer.syncSongCB = { song in
      if song.id == "valid" { song.title = "Title" }
    }

    let result = await createSyncer().repairSongsWithoutMetadata()

    XCTAssertEqual(result.fetched, 1)
    XCTAssertEqual(result.removedLeftovers, 1)
    XCTAssertTrue(storage.main.library.getSongsWithoutMetadata(for: account).isEmpty)
    XCTAssertNil(storage.main.library.getSong(for: account, id: "gone"))
  }

  func testRepair_OfflineModeFetchesAndRemovesNothing() async {
    createSongWithoutMetadata(id: "gone", account: account)
    library.saveContext()
    var requestCount = 0
    librarySyncer.syncSongCB = { _ in requestCount += 1 }
    storage.settings.user.isOfflineMode = true

    let result = await createSyncer().repairSongsWithoutMetadata()

    XCTAssertEqual(requestCount, 0)
    XCTAssertEqual(result.removedLeftovers, 0)
    XCTAssertNotNil(storage.main.library.getSong(for: account, id: "gone"))
  }
}
