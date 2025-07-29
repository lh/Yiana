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
    @State private var pages: [PDFPage] = []
    @State private var selectedPages: Set<Int> = []
    @State private var isEditMode = false
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
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
                
                // Edit/Done button
                ToolbarItem(placement: .automatic) {
                    Button(isEditMode ? "Done" : "Edit") {
                        withAnimation {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedPages.removeAll()
                            }
                        }
                    }
                }
                
                #if os(iOS)
                if isEditMode && !selectedPages.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            deleteSelectedPages()
                        } label: {
                            Label("Delete Selected", systemImage: "trash")
                        }
                    }
                }
                #else
                if isEditMode && !selectedPages.isEmpty {
                    ToolbarItemGroup(placement: .automatic) {
                        // Move up button
                        if selectedPages.count == 1, let selectedIndex = selectedPages.first, selectedIndex > 0 {
                            Button {
                                moveSelectedPage(direction: -1)
                            } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                        }
                        
                        // Move down button
                        if selectedPages.count == 1, let selectedIndex = selectedPages.first, selectedIndex < pages.count - 1 {
                            Button {
                                moveSelectedPage(direction: 1)
                            } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                        }
                        
                        Button(role: .destructive) {
                            deleteSelectedPages()
                        } label: {
                            Label("Delete Selected", systemImage: "trash")
                        }
                    }
                }
                #endif
            }
            #if os(iOS)
            .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
            #endif
            #if os(iOS)
            .toolbar(.visible, for: .bottomBar)
            #endif
        }
        .onAppear {
            loadPages()
        }
    }
    
    private var pageGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    PageThumbnailView(
                        page: page,
                        pageNumber: index + 1,
                        isSelected: selectedPages.contains(index),
                        isEditMode: isEditMode
                    )
                    .onTapGesture {
                        if isEditMode {
                            toggleSelection(for: index)
                        }
                    }
                    #if os(iOS)
                    .onDrag {
                        self.draggedPage = index
                        return NSItemProvider(object: "\(index)" as NSString)
                    }
                    .onDrop(of: [.text], isTargeted: nil) { providers, location in
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
        guard let pdfData = pdfData,
              let document = PDFDocument(data: pdfData) else { return }
        
        pages = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                pages.append(page)
            }
        }
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
    }
    
    private func reorderPages(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex else { return }
        
        let page = pages.remove(at: sourceIndex)
        pages.insert(page, at: destinationIndex)
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
        // Create new PDF document with reordered pages
        let newDocument = PDFDocument()
        
        for (index, page) in pages.enumerated() {
            newDocument.insert(page, at: index)
        }
        
        pdfData = newDocument.dataRepresentation()
        isPresented = false
    }
}

struct PageThumbnailView: View {
    let page: PDFPage
    let pageNumber: Int
    let isSelected: Bool
    let isEditMode: Bool
    
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
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                    )
                
                // Selection indicator
                if isEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .gray)
                        .background(Circle().fill(Color.white))
                        .padding(8)
                }
            }
            
            // Page number
            Text("Page \(pageNumber)")
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