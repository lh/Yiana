#if os(iOS)
import SwiftUI
import PDFKit
import UIKit

struct ThumbnailSidebarView: View {
    let document: PDFDocument
    let currentPage: Int
    let provisionalPageRange: Range<Int>?
    let thumbnailSize: SidebarThumbnailSize
    let isSelecting: Bool
    let selectedPages: Set<Int>
    var onTap: (Int) -> Void
    var onDoubleTap: (Int) -> Void
    var onClearSelection: (() -> Void)? = nil
    var onToggleSelectionMode: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if let onToggleSelectionMode {
                    Button(isSelecting ? "Done" : "Select") {
                        onToggleSelectionMode()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                Spacer()
                if isSelecting {
                    Text("\(selectedPages.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    if let onClearSelection {
                        Button("Clear") { onClearSelection() }
                            .font(.footnote)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        if let page = document.page(at: index) {
                            ThumbnailCell(
                                page: page,
                                index: index,
                                isCurrent: index == currentPage,
                                isSelected: selectedPages.contains(index),
                                isSelecting: isSelecting,
                                isProvisional: provisionalPageRange?.contains(index) ?? false,
                                thumbnailSize: thumbnailSize,
                                onTap: { onTap(index) },
                                onDoubleTap: { onDoubleTap(index) }
                            )
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
            }
        }
        .frame(width: thumbnailSize.sidebarWidth)
        .background(Color(.secondarySystemBackground))
        .accessibilityLabel("Page thumbnails")
    }
}

private struct ThumbnailCell: View {
    let page: PDFPage
    let index: Int
    let isCurrent: Bool
    let isSelected: Bool
    let isSelecting: Bool
    let isProvisional: Bool
    let thumbnailSize: SidebarThumbnailSize
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

                if isSelecting {
                    SelectionBadge(isSelected: isSelected)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        if isCurrent {
            return Color.accentColor
        } else if isProvisional {
            return Color.yellow
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        if isCurrent {
            return 3
        } else if isProvisional {
            return 2
        } else if isSelecting {
            return 1
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

private struct SelectionBadge: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 20, height: 20)
                .shadow(radius: 1)
            Circle()
                .stroke(Color.accentColor, lineWidth: 1)
                .frame(width: 18, height: 18)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18))
            }
        }
    }
}

#endif
