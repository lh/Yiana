//
//  DocumentListItem.swift
//  Yiana
//
//  Lightweight struct for rendering document rows from the GRDB cache.
//  Never opens a .yianazip file.

import Foundation

struct DocumentListItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let title: String
    let folderPath: String
    let createdDate: Date
    let modifiedDate: Date
    let fileSize: Int64
    let pageCount: Int
    let ocrCompleted: Bool
    let hasPendingTextPage: Bool
    let tags: [String]
    let isPlaceholder: Bool

    var isPinned: Bool {
        tags.contains { $0.caseInsensitiveCompare("pinned") == .orderedSame }
    }

    /// Create from a GRDB metadata record
    init(record: SearchIndexService.DocumentMetadataRecord) {
        self.id = UUID(uuidString: record.documentId) ?? UUID()
        self.url = URL(fileURLWithPath: record.url)
        self.title = record.title
        self.folderPath = record.folderPath
        self.createdDate = Date(timeIntervalSince1970: record.createdDate)
        self.modifiedDate = Date(timeIntervalSince1970: record.modifiedDate)
        self.fileSize = record.fileSize
        self.pageCount = record.pageCount
        self.ocrCompleted = record.ocrCompleted
        self.hasPendingTextPage = record.hasPendingTextPage
        self.tags = record.tagsCsv.isEmpty ? [] : record.tagsCsv.components(separatedBy: ",")
        self.isPlaceholder = record.isPlaceholder
    }

    /// Create from a search result
    init(searchResult: SearchIndexService.IndexedSearchResult) {
        self.id = searchResult.documentId
        self.url = searchResult.url
        self.title = searchResult.title
        self.folderPath = searchResult.folderPath
        self.createdDate = searchResult.createdDate
        self.modifiedDate = searchResult.modifiedDate
        self.fileSize = searchResult.fileSize
        self.pageCount = searchResult.pageCount
        self.ocrCompleted = searchResult.ocrCompleted
        self.hasPendingTextPage = searchResult.hasPendingTextPage
        self.tags = searchResult.tagsCsv.isEmpty ? [] : searchResult.tagsCsv.components(separatedBy: ",")
        self.isPlaceholder = false
    }
}
