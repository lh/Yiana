//
//  URL+FolderPath.swift
//  Yiana
//
//  Shared utility for deriving folder paths relative to the documents directory.
//

import Foundation

extension URL {
    /// Derive the folder path relative to the given documents directory.
    ///
    /// For a URL like `.../Documents/Receipts/scan.yianazip` with a documents
    /// directory of `.../Documents`, this returns `"Receipts"`.
    /// For files directly in the documents directory, returns `""`.
    func relativeFolderPath(relativeTo documentsDir: URL) -> String {
        // resolvingSymlinksInPath() resolves the /private ↔ /var symlink on iOS;
        // standardizedFileURL does NOT resolve symlinks and fails here.
        let parentPath = self.resolvingSymlinksInPath().deletingLastPathComponent().path
        let docsPath = documentsDir.resolvingSymlinksInPath().path
        let relative = parentPath.replacingOccurrences(of: docsPath, with: "")
        if relative.hasPrefix("/") {
            return String(relative.dropFirst())
        }
        return relative
    }
}
