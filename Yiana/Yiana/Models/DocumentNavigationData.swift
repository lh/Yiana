//
//  DocumentNavigationData.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation

/// Navigation data for opening a document with optional search context
struct DocumentNavigationData: Hashable {
    let url: URL
    let searchResult: SearchResult?

    init(url: URL, searchResult: SearchResult? = nil) {
        self.url = url
        self.searchResult = searchResult
    }

    static func == (lhs: DocumentNavigationData, rhs: DocumentNavigationData) -> Bool {
        lhs.url == rhs.url && lhs.searchResult?.id == rhs.searchResult?.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(searchResult?.id)
    }
}
