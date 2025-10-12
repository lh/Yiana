import Foundation

extension Notification.Name {
    /// Notification to copy pages from the current document
    static let copyPages = Notification.Name("com.vitygas.Yiana.copyPages")

    /// Notification to cut pages from the current document
    static let cutPages = Notification.Name("com.vitygas.Yiana.cutPages")

    /// Notification to paste pages into the current document
    static let pastePages = Notification.Name("com.vitygas.Yiana.pastePages")
}