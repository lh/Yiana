//
//  AnnotationTool.swift
//  Yiana
//
//  Defines the protocol and implementations for macOS text annotation tools
//  Following the "Digital Paper" paradigm - annotations are permanent once committed
//

#if os(macOS)
import Foundation
import PDFKit
import AppKit
import SwiftUI

extension CGRect {
    var isFinite: Bool {
        return origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite
    }
}

// MARK: - AnnotationTool Protocol

protocol AnnotationTool {
    var toolType: AnnotationToolType { get }
    var isConfigurable: Bool { get }
    
    func createAnnotation(at point: CGPoint, on page: PDFPage) -> PDFAnnotation?
    func createAnnotation(from startPoint: CGPoint, to endPoint: CGPoint, on page: PDFPage) -> PDFAnnotation?
    func configureAnnotation(_ annotation: PDFAnnotation)
}

// MARK: - Tool Type Enumeration

enum AnnotationToolType: String, CaseIterable {
    case text = "Text"
    case highlight = "Highlight"
    case underline = "Underline"
    case strikeout = "Strikeout"
    
    var icon: String {
        switch self {
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikeout: return "strikethrough"
        }
    }
    
    var shortcutKey: String {
        switch self {
        case .text: return "t"
        case .highlight: return "h"
        case .underline: return "u"
        case .strikeout: return "s"
        }
    }
}

// MARK: - Base Implementation

class BaseAnnotationTool: AnnotationTool {
    var toolType: AnnotationToolType
    var isConfigurable: Bool { true }
    
    init(toolType: AnnotationToolType) {
        self.toolType = toolType
    }
    
    func createAnnotation(at point: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        return nil
    }
    
    func createAnnotation(from startPoint: CGPoint, to endPoint: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        return nil
    }
    
    func configureAnnotation(_ annotation: PDFAnnotation) {
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
    }
}

// MARK: - Text Tool

class TextTool: BaseAnnotationTool {
    var font: NSFont = .systemFont(ofSize: 14)
    var color: NSColor = .black
    var alignment: NSTextAlignment = .left
    
    init() {
        super.init(toolType: .text)
    }
    
    override func createAnnotation(at point: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        let bounds = CGRect(x: point.x, y: point.y, width: 200, height: 50)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        
        // Configure for editing - simplified approach
        annotation.contents = "Click to edit"
        annotation.font = font
        annotation.fontColor = color
        annotation.color = NSColor.white.withAlphaComponent(0.9) // Slightly more opaque
        annotation.alignment = alignment
        
        // Essential properties for freeText annotations
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        annotation.isReadOnly = false
        
        // Set border for visibility
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 1.0
        annotation.border?.style = .solid
        
        configureAnnotation(annotation)
        return annotation
    }
    
    override func configureAnnotation(_ annotation: PDFAnnotation) {
        super.configureAnnotation(annotation)
        annotation.font = font
        annotation.fontColor = color
        annotation.alignment = alignment
    }
}

// MARK: - Highlight Tool

class HighlightTool: BaseAnnotationTool {
    var color: NSColor = NSColor.yellow.withAlphaComponent(0.5)
    
    init() {
        super.init(toolType: .highlight)
    }
    
    override func createAnnotation(from startPoint: CGPoint, to endPoint: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        // Try to create text selection first
        if let selection = page.selection(from: startPoint, to: endPoint), let selectionString = selection.string, !selectionString.isEmpty {
            let bounds = selection.bounds(for: page)
            
            // Validate bounds
            guard bounds.isFinite && !bounds.isEmpty else {
                print("DEBUG: Selection bounds invalid: \(bounds)")
                return createRectangleHighlight(from: startPoint, to: endPoint)
            }
            
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = color
            configureAnnotation(annotation)
            return annotation
        } else {
            // Fallback to rectangle-based highlight
            print("DEBUG: No text selection found, creating rectangle highlight")
            return createRectangleHighlight(from: startPoint, to: endPoint)
        }
    }
    
    private func createRectangleHighlight(from startPoint: CGPoint, to endPoint: CGPoint) -> PDFAnnotation? {
        // Create a rectangle from the two points
        let minX = min(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxX = max(startPoint.x, endPoint.x)
        let maxY = max(startPoint.y, endPoint.y)
        
        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        
        // Ensure minimum size
        let finalBounds = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: max(bounds.width, 20),
            height: max(bounds.height, 10)
        )
        
        let annotation = PDFAnnotation(bounds: finalBounds, forType: .square, withProperties: nil)
        annotation.color = color
        annotation.interiorColor = color
        configureAnnotation(annotation)
        return annotation
    }
    
    override func configureAnnotation(_ annotation: PDFAnnotation) {
        super.configureAnnotation(annotation)
        annotation.color = color
    }
}

// MARK: - Underline Tool

class UnderlineTool: BaseAnnotationTool {
    var color: NSColor = .black
    
    init() {
        super.init(toolType: .underline)
    }
    
    override func createAnnotation(from startPoint: CGPoint, to endPoint: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        guard let selection = page.selection(from: startPoint, to: endPoint) else { return nil }
        
        let bounds = selection.bounds(for: page)
        let annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
        
        annotation.color = color
        configureAnnotation(annotation)
        return annotation
    }
    
    override func configureAnnotation(_ annotation: PDFAnnotation) {
        super.configureAnnotation(annotation)
        annotation.color = color
    }
}

// MARK: - Strikeout Tool

class StrikeoutTool: BaseAnnotationTool {
    var color: NSColor = .red
    
    init() {
        super.init(toolType: .strikeout)
    }
    
    override func createAnnotation(from startPoint: CGPoint, to endPoint: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        guard let selection = page.selection(from: startPoint, to: endPoint) else { return nil }
        
        let bounds = selection.bounds(for: page)
        let annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
        
        annotation.color = color
        configureAnnotation(annotation)
        return annotation
    }
    
    override func configureAnnotation(_ annotation: PDFAnnotation) {
        super.configureAnnotation(annotation)
        annotation.color = color
    }
}

// MARK: - Tool Factory

class AnnotationToolFactory {
    static func createTool(for type: AnnotationToolType) -> AnnotationTool {
        switch type {
        case .text:
            return TextTool()
        case .highlight:
            return HighlightTool()
        case .underline:
            return UnderlineTool()
        case .strikeout:
            return StrikeoutTool()
        }
    }
}

#endif
