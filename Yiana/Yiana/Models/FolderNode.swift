import Foundation

/// Tree node for sidebar folder hierarchy.
/// `relativePath` is the path relative to the documents root (empty string = root).
struct FolderNode: Identifiable, Hashable {
    var id: String { relativePath }
    let name: String
    let url: URL
    let relativePath: String
    var children: [FolderNode]

    /// Returns children wrapped in Optional for SwiftUI `List(children:)`.
    /// Empty arrays become nil so leaf nodes don't show disclosure arrows.
    var childrenOrNil: [FolderNode]? {
        children.isEmpty ? nil : children
    }
}
