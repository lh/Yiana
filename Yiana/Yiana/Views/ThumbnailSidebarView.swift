#if os(iOS)
import SwiftUI
import PDFKit
import UIKit

enum SidebarEditAction {
    case toggleSelection(Int)
    case delete, duplicate, cut, copy, paste, restoreCut
    case move(IndexSet, Int)
    case done
}

struct ThumbnailSidebarView: View {
    let document: PDFDocument
    let currentPage: Int
    let provisionalPageRange: Range<Int>?
    let thumbnailSize: SidebarThumbnailSize
    let refreshID: UUID
    var onTap: (Int) -> Void
    var onDoubleTap: (Int) -> Void

    // Edit mode parameters
    var isEditing: Bool = false
    var selectedPages: Set<Int> = []
    var cutPageIndices: Set<Int>?
    var clipboardHasPayload: Bool = false
    var hasCutToRestore: Bool = false
    var onEditAction: ((SidebarEditAction) -> Void)?

    private var hasSelection: Bool { !selectedPages.isEmpty }
    private var pageIndices: [Int] { Array(0..<document.pageCount) }

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                editModeToolbar
            }

            List {
                ForEach(pageIndices, id: \.self) { index in
                    if let page = document.page(at: index) {
                        let isProvisional = provisionalPageRange?.contains(index) ?? false
                        let isCut = cutPageIndices?.contains(index) ?? false
                        ThumbnailCell(
                            page: page,
                            index: index,
                            isCurrent: index == currentPage,
                            isProvisional: isProvisional,
                            thumbnailSize: thumbnailSize,
                            isEditing: isEditing,
                            isSelected: selectedPages.contains(index),
                            isCut: isCut,
                            onTap: { onTap(index) },
                            onDoubleTap: { onDoubleTap(index) }
                        )
                        .opacity(isCut ? 0.4 : 1.0)
                        .overlay(isCut ? Color.red.opacity(0.1) : Color.clear)
                        .moveDisabled(isProvisional)
                        .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .onMove { source, destination in
                    onEditAction?(.move(source, destination))
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .id(refreshID)
        }
        .frame(width: thumbnailSize.sidebarWidth)
        .background(Color(.secondarySystemBackground))
        .accessibilityLabel("Page thumbnails")
    }

    private var editModeToolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { onEditAction?(.done) } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                }
                .padding(.leading, 12)

                Spacer()

                HStack(spacing: 4) {
                    Button { onEditAction?(.cut) } label: {
                        Image(systemName: "scissors")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!hasSelection)

                    Button { onEditAction?(.copy) } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!hasSelection)

                    Button { onEditAction?(.paste) } label: {
                        Image(systemName: "doc.on.clipboard")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!clipboardHasPayload)

                    Button { onEditAction?(.duplicate) } label: {
                        Image(systemName: "plus.square.on.square")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!hasSelection)

                    Button(role: .destructive) { onEditAction?(.delete) } label: {
                        Image(systemName: "trash")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!hasSelection)
                }
                .font(.footnote)
                .padding(.trailing, 8)
            }
            .frame(height: 44)

            if hasCutToRestore {
                Button { onEditAction?(.restoreCut) } label: {
                    Label("Restore Cut", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .padding(.bottom, 4)
            }

            Divider()
        }
        .background(Color(.secondarySystemBackground))
    }
}

private struct ThumbnailCell: View {
    let page: PDFPage
    let index: Int
    let isCurrent: Bool
    let isProvisional: Bool
    let thumbnailSize: SidebarThumbnailSize
    let isEditing: Bool
    let isSelected: Bool
    let isCut: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                    .frame(width: thumbnailSize.thumbnailSize.width, height: thumbnailSize.thumbnailSize.height)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )

                if isProvisional {
                    DraftTag()
                        .padding(6)
                }

                if isEditing && !isProvisional {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .gray)
                        .background(Circle().fill(Color.white))
                        .padding(6)
                }
            }

            Text("Page \(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .highPriorityGesture(TapGesture().onEnded { onTap() })
        .onAppear(perform: renderThumbnail)
    }

    private var borderColor: Color {
        if isEditing && isSelected {
            return Color.accentColor
        } else if isCurrent {
            return Color.accentColor
        } else if isProvisional {
            return Color.yellow
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        if isEditing && isSelected {
            return 3
        } else if isCurrent {
            return 3
        } else if isProvisional {
            return 2
        } else {
            return 0
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                ProgressView()
            }
        }
    }

    private func renderThumbnail() {
        guard image == nil else { return }
        let size = thumbnailSize.thumbnailSize
        DispatchQueue.global(qos: .userInitiated).async {
            let rendered = page.thumbnail(of: size, for: .mediaBox)
            DispatchQueue.main.async {
                self.image = rendered
            }
        }
    }
}

private struct DraftTag: View {
    var body: some View {
        Text("Draft")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.yellow.opacity(0.9))
            .foregroundColor(.black)
            .clipShape(Capsule())
            .accessibilityLabel("Draft page")
    }
}

#endif
