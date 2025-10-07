//
//  DebugRenderedPageStore.swift
//  Yiana
//
//  Writes the most recently rendered text page to disk when running in DEBUG
//  so it can be inspected via Files.app.
//

import Foundation

#if DEBUG
struct DebugRenderedPageStore {
    static let shared = DebugRenderedPageStore()
    private init() {}

    func store(data: Data, near documentURL: URL) {
        let debugURL = documentURL.deletingLastPathComponent()
            .appendingPathComponent("_Debug-Rendered-Text-Page.pdf")
        do {
            try data.write(to: debugURL, options: .atomic)
            print("DEBUG DebugRenderedPageStore: wrote rendered text page to \(debugURL.path)")
        } catch {
            print("DEBUG DebugRenderedPageStore: failed to write rendered text page: \(error)")
        }
    }
}
#endif
