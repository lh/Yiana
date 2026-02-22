import Foundation

extension Notification.Name {
    /// Notification to copy pages from the current document
    static let copyPages = Notification.Name("com.vitygas.Yiana.copyPages")

    /// Notification to cut pages from the current document
    static let cutPages = Notification.Name("com.vitygas.Yiana.cutPages")

    /// Notification to paste pages into the current document
    static let pastePages = Notification.Name("com.vitygas.Yiana.pastePages")
}

extension Notification.Name {
    /// Notification to print the current document (macOS Cmd+P)
    static let printDocument = Notification.Name("com.vitygas.Yiana.printDocument")
}
