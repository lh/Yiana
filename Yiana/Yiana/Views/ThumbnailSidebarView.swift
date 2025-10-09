#if os(iOS)
import SwiftUI
import PDFKit
import UIKit

struct ThumbnailSidebarView: View {
    let document: PDFDocument
    let currentPage: Int
    let provisionalPageRange: Range<Int>?
    let thumbnailSize: SidebarThumbnailSize
    var onSelect: (Int) -> Void
    var onDoubleTap: ((Int) -> Void)? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<document.pageCount, id: \.self) { index in
                    if let page = document.page(at: index) {
                        ThumbnailCell(
                            page: page,
                            index: index,
                            isCurrent: index == currentPage,
                            isProvisional: provisionalPageRange?.contains(index) ?? false,
                            thumbnailSize: thumbnailSize,
                            onTap: { onSelect(index) },
                            onDoubleTap: { onDoubleTap?(index) }
                        )
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
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
            }

            Text("Page \(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onTapGesture(count: 2, perform: onDoubleTap)
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
        } else {
            return 1
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
