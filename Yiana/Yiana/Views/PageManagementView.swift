//
//  PageManagementView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
import PDFKit

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

struct PageManagementView: View {
    @Binding var pdfData: Data?
    @Binding var isPresented: Bool
    var currentPageIndex: Int = 0  // The page currently being viewed
    var displayPDFData: Data? = nil
    var provisionalPageRange: Range<Int>? = nil
    var onPageSelected: ((Int) -> Void)? = nil  // Callback for navigation
    var onProvisionalPageSelected: (() -> Void)? = nil
    @State private var pages: [PDFPage] = []
    @State private var selectedPages: Set<Int> = []
    @State private var isEditMode = false  // Start in navigation mode
    @State private var navigateToPage: Int? = nil  // Track navigation request
    @State private var pendingNavigationIndex: Int? = nil  // Show where we're about to navigate
    @State private var showProvisionalReorderAlert = false
    @State private var workingDocument: PDFDocument?
    #if os(iOS)
    @State private var draggedPage: Int?
    #endif
    
    var body: some View {
        NavigationStack {
            Group {
                if pages.isEmpty {
                    ContentUnavailableView(
                        "No Pages",
                        systemImage: "doc.text",
                        description: Text("This document has no pages")
                    )
                } else {
                    pageGrid
                }
            }
            .navigationTitle("Manage Pages")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditMode {
                        // Exit selection mode
                        Button("Cancel") {
                            selectedPages.removeAll()
                            isEditMode = false
                        }
                    }
                }
                
                #if os(iOS)
                if !selectedPages.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            deleteSelectedPages()
                        } label: {
                            Label("Delete Selected", systemImage: "trash")
                        }
                    }
                }
                #else
                ToolbarItemGroup(placement: .automatic) {
                        // Move up button - always visible but disabled when inappropriate
                        Button {
                            moveSelectedPage(direction: -1)
                        } label: {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                        .disabled(selectedPages.count != 1 || selectedPages.first == 0)
                        
                        // Move down button - always visible but disabled when inappropriate
                        Button {
                            moveSelectedPage(direction: 1)
                        } label: {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                        .disabled(selectedPages.count != 1 || (selectedPages.first ?? 0) >= pages.count - 1)
                        
                        // Delete button - disabled when nothing selected
                        Button(role: .destructive) {
                            deleteSelectedPages()
                        } label: {
                            Label("Delete Selected", systemImage: "trash")
                        }
                        .disabled(selectedPages.isEmpty)
                }
                #endif
            }
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            #if os(iOS)
            .toolbar(.visible, for: .bottomBar)
            #endif
        }
        .onAppear {
            loadPages()
        }
        .alert("Finish Editing", isPresented: $showProvisionalReorderAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Save or discard the draft text page before reordering.")
        }
        .onChange(of: displayPDFData) { _, _ in
            loadPages()
        }
        .onChange(of: pdfData) { _, _ in
            loadPages()
        }
    }
    
    private var pageGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    let isProvisional = provisionalPageRange?.contains(index) ?? false
                    PageThumbnailView(
                        page: page,
                        pageNumber: index + 1,
                        isSelected: selectedPages.contains(index),
                        isCurrentPage: pendingNavigationIndex == index ? true : (pendingNavigationIndex == nil && index == currentPageIndex),
                        isEditMode: isEditMode,
                        isProvisional: isProvisional
                    )
                    .onTapGesture {
                        if isProvisional {
                            if !isEditMode {
                                onProvisionalPageSelected?()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isPresented = false
                                }
                            }
                            return
                        }
                        if isEditMode {
                            toggleSelection(for: index)
                        } else if let callback = onPageSelected {
                            pendingNavigationIndex = index
                            callback(index)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isPresented = false
                            }
                        }
                    }
                    .onTapGesture(count: 2) {
                        if !isEditMode && !isProvisional {
                            isEditMode = true
                            selectedPages.insert(index)
                        }
                    }
                    #if os(iOS)
                    .onDrag {
                        guard !isProvisional else { return NSItemProvider() }
                        self.draggedPage = index
                        return NSItemProvider(object: "\(index)" as NSString)
                    }
                    .onDrop(of: [.text], isTargeted: nil) { providers, location in
                        guard !isProvisional else { return false }
                        guard let draggedPage = self.draggedPage,
                              draggedPage != index else { return false }
                        
                        reorderPages(from: draggedPage, to: index)
                        return true
                    }
                    #endif
                }
            }
            .padding()
        }
    }
    
    private func loadPages() {
        let hasProvisional = provisionalPageRange.map { !$0.isEmpty } ?? false
        let sourceData: Data?
        if hasProvisional, let displayData = displayPDFData {
            sourceData = displayData
        } else if let baseData = pdfData {
            sourceData = baseData
        } else {
            sourceData = displayPDFData
        }

        guard let selectedData = sourceData,
              let document = PDFDocument(data: selectedData) else {
            pages = []
            workingDocument = nil
            return
        }

        var loadedPages: [PDFPage] = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                loadedPages.append(page)
            }
        }
        pages = loadedPages
        workingDocument = document
    }
    
    private func toggleSelection(for index: Int) {
        if selectedPages.contains(index) {
            selectedPages.remove(index)
        } else {
            selectedPages.insert(index)
        }
    }
    
    private func deleteSelectedPages() {
        // Remove pages in reverse order to maintain indices
        let sortedIndices = selectedPages.sorted(by: >)
        for index in sortedIndices {
            if index < pages.count {
                pages.remove(at: index)
            }
        }
        selectedPages.removeAll()
        // Stay in edit mode after deletion
        
        // Update the PDF data
        saveChanges()
    }
    
    private func reorderPages(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex else { return }

        if let range = provisionalPageRange,
           range.contains(sourceIndex) || range.contains(destinationIndex) {
            showProvisionalReorderAlert = true
            return
        }

        let page = pages.remove(at: sourceIndex)
        pages.insert(page, at: destinationIndex)
        
        // Update the PDF data
        saveChanges()
    }
    
    #if os(macOS)
    private func moveSelectedPage(direction: Int) {
        guard let selectedIndex = selectedPages.first else { return }
        let newIndex = selectedIndex + direction
        
        guard newIndex >= 0 && newIndex < pages.count else { return }
        
        // Reorder the page
        reorderPages(from: selectedIndex, to: newIndex)
        
        // Update selection to follow the moved page
        selectedPages.removeAll()
        selectedPages.insert(newIndex)
    }
    #endif
    
    private func saveChanges() {
        guard !pages.isEmpty else {
            let emptyDocument = PDFDocument()
            pdfData = emptyDocument.dataRepresentation()
            loadPages()
            return
        }

        guard let document = workingDocument else {
            // Fallback to reloading if we somehow lost the reference
            loadPages()
            return
        }

        let targetOrder: [Int] = pages.compactMap { page in
            document.index(for: page)
        }

        guard targetOrder.count == pages.count else {
            // If any mapping failed, reload to avoid corrupting data
            loadPages()
            return
        }

        var currentOrder = Array(0..<document.pageCount)

        for targetIndex in 0..<targetOrder.count {
            let desiredOriginalIndex = targetOrder[targetIndex]
            guard let currentIndex = currentOrder.firstIndex(of: desiredOriginalIndex) else {
                continue
            }
            if currentIndex == targetIndex {
                continue
            }
            document.exchangePage(at: targetIndex, withPageAt: currentIndex)
            currentOrder.swapAt(targetIndex, currentIndex)
        }

        if document.pageCount > pages.count {
            for index in stride(from: document.pageCount - 1, through: pages.count, by: -1) {
                document.removePage(at: index)
            }
        }

        guard let fullData = document.dataRepresentation(),
              let persistedDocument = PDFDocument(data: fullData) else {
            loadPages()
            return
        }

        if let range = provisionalPageRange {
            for index in range.reversed() where index < persistedDocument.pageCount {
                persistedDocument.removePage(at: index)
            }
        }

        guard let updatedData = persistedDocument.dataRepresentation() else {
            loadPages()
            return
        }

        pdfData = updatedData
        workingDocument = persistedDocument
        // Don't dismiss - let user continue working
    }
}

struct PageThumbnailView: View {
    let page: PDFPage
    let pageNumber: Int
    let isSelected: Bool
    let isCurrentPage: Bool
    let isEditMode: Bool
    let isProvisional: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Page thumbnail
                thumbnailImage
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isProvisional ? Color.yellow.opacity(0.9) : (isCurrentPage ? Color.blue : (isSelected ? Color.accentColor : Color.gray.opacity(0.3))),
                                lineWidth: isProvisional ? 3 : (isCurrentPage ? 4 : (isSelected ? 3 : 1))
                            )
                    )
                    .overlay(alignment: .topLeading) {
                        if isProvisional {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                Text("Draft")
                                    .fontWeight(.semibold)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.9))
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                            .padding(8)
                        }
                    }
                
                // Selection indicator (only show in edit mode)
                if isEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .gray)
                        .background(Circle().fill(Color.white))
                        .padding(8)
                }
            }
            
            // Page number
            Text(isProvisional ? "Page \(pageNumber) (Draft)" : "Page \(pageNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var thumbnailImage: some View {
        if let thumbnail = generateThumbnail(for: page) {
            #if os(iOS)
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
            #else
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
            #endif
        } else {
            Image(systemName: "doc.text")
                .foregroundColor(.gray)
                .font(.largeTitle)
        }
    }
    
    #if os(iOS)
    private func generateThumbnail(for page: PDFPage) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let thumbnailSize = CGSize(width: 120 * scale, height: 150 * scale)
        
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))
            
            context.cgContext.translateBy(x: 0, y: thumbnailSize.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            
            let scaleFactor = min(thumbnailSize.width / pageRect.width, 
                                thumbnailSize.height / pageRect.height)
            context.cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
    #else
    private func generateThumbnail(for page: PDFPage) -> NSImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let thumbnailSize = CGSize(width: 120 * scale, height: 150 * scale)
        
        let image = NSImage(size: thumbnailSize)
        image.lockFocus()
        
        NSColor.white.setFill()
        NSRect(origin: .zero, size: thumbnailSize).fill()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.translateBy(x: 0, y: thumbnailSize.height)
            context.scaleBy(x: 1, y: -1)
            
            let scaleFactor = min(thumbnailSize.width / pageRect.width, 
                                thumbnailSize.height / pageRect.height)
            context.scaleBy(x: scaleFactor, y: scaleFactor)
            
            page.draw(with: .mediaBox, to: context)
        }
        
        image.unlockFocus()
        return image
    }
    #endif
}
