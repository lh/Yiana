//
//  AnnotationToolTests.swift
//  YianaTests
//
//  Unit tests for annotation tools
//

#if os(macOS)
import XCTest
import PDFKit
@testable import Yiana

class AnnotationToolTests: XCTestCase {
    
    var pdfDocument: PDFDocument!
    var testPage: PDFPage!
    
    override func setUp() {
        super.setUp()
        
        // Create a test PDF document
        pdfDocument = PDFDocument()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        testPage = PDFPage()
        
        // If we can't create a page directly, create from data
        if testPage == nil {
            let pdfData = NSMutableData()
            let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
            var mediaBox = pageRect
            let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!
            
            pdfContext.beginPDFPage(nil)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
            
            pdfDocument = PDFDocument(data: pdfData as Data)
            testPage = pdfDocument.page(at: 0)
        }
    }
    
    override func tearDown() {
        pdfDocument = nil
        testPage = nil
        super.tearDown()
    }
    
    // MARK: - Text Tool Tests
    
    func testTextToolCreation() {
        let tool = TextTool()
        
        XCTAssertEqual(tool.toolType, .text)
        XCTAssertTrue(tool.isConfigurable)
        XCTAssertNotNil(tool.font)
        XCTAssertNotNil(tool.color)
    }
    
    func testTextToolAnnotationCreation() {
        let tool = TextTool()
        let point = CGPoint(x: 100, y: 100)
        
        let annotation = tool.createAnnotation(at: point, on: testPage)
        
        XCTAssertNotNil(annotation)
        XCTAssertEqual(annotation?.type, PDFAnnotationSubtype.freeText.rawValue)
        XCTAssertEqual(annotation?.bounds.origin.x, point.x)
        XCTAssertEqual(annotation?.bounds.origin.y, point.y)
    }
    
    func testTextToolConfiguration() {
        let tool = TextTool()
        tool.font = .systemFont(ofSize: 18)
        tool.color = .red
        
        let annotation = tool.createAnnotation(at: CGPoint(x: 50, y: 50), on: testPage)
        
        XCTAssertNotNil(annotation)
        XCTAssertEqual(annotation?.font?.pointSize, 18)
        XCTAssertEqual(annotation?.fontColor, .red)
    }
    
    // MARK: - Highlight Tool Tests
    
    func testHighlightToolCreation() {
        let tool = HighlightTool()
        
        XCTAssertEqual(tool.toolType, .highlight)
        XCTAssertTrue(tool.isConfigurable)
        XCTAssertNotNil(tool.color)
    }
    
    func testHighlightToolAnnotationCreation() {
        let tool = HighlightTool()
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 200, y: 100)
        
        // Note: This might return nil without actual text to select
        let annotation = tool.createAnnotation(from: startPoint, to: endPoint, on: testPage)
        
        if annotation != nil {
            XCTAssertEqual(annotation?.type, PDFAnnotationSubtype.highlight.rawValue)
        }
    }
    
    func testHighlightToolColorConfiguration() {
        let tool = HighlightTool()
        let customColor = NSColor.green.withAlphaComponent(0.3)
        tool.color = customColor
        
        XCTAssertEqual(tool.color, customColor)
    }
    
    // MARK: - Underline Tool Tests
    
    func testUnderlineToolCreation() {
        let tool = UnderlineTool()
        
        XCTAssertEqual(tool.toolType, .underline)
        XCTAssertTrue(tool.isConfigurable)
        XCTAssertEqual(tool.color, .black)
    }
    
    func testUnderlineToolAnnotationCreation() {
        let tool = UnderlineTool()
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 200, y: 100)
        
        let annotation = tool.createAnnotation(from: startPoint, to: endPoint, on: testPage)
        
        if annotation != nil {
            XCTAssertEqual(annotation?.type, PDFAnnotationSubtype.underline.rawValue)
        }
    }
    
    // MARK: - Strikeout Tool Tests
    
    func testStrikeoutToolCreation() {
        let tool = StrikeoutTool()
        
        XCTAssertEqual(tool.toolType, .strikeout)
        XCTAssertTrue(tool.isConfigurable)
        XCTAssertEqual(tool.color, .red)
    }
    
    func testStrikeoutToolAnnotationCreation() {
        let tool = StrikeoutTool()
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 200, y: 100)
        
        let annotation = tool.createAnnotation(from: startPoint, to: endPoint, on: testPage)
        
        if annotation != nil {
            XCTAssertEqual(annotation?.type, PDFAnnotationSubtype.strikeOut.rawValue)
        }
    }
    
    // MARK: - Tool Factory Tests
    
    func testToolFactoryCreatesCorrectTools() {
        let textTool = AnnotationToolFactory.createTool(for: .text)
        XCTAssertTrue(textTool is TextTool)
        XCTAssertEqual(textTool.toolType, .text)
        
        let highlightTool = AnnotationToolFactory.createTool(for: .highlight)
        XCTAssertTrue(highlightTool is HighlightTool)
        XCTAssertEqual(highlightTool.toolType, .highlight)
        
        let underlineTool = AnnotationToolFactory.createTool(for: .underline)
        XCTAssertTrue(underlineTool is UnderlineTool)
        XCTAssertEqual(underlineTool.toolType, .underline)
        
        let strikeoutTool = AnnotationToolFactory.createTool(for: .strikeout)
        XCTAssertTrue(strikeoutTool is StrikeoutTool)
        XCTAssertEqual(strikeoutTool.toolType, .strikeout)
    }
    
    // MARK: - Tool Type Tests
    
    func testToolTypeProperties() {
        XCTAssertEqual(AnnotationToolType.text.icon, "textformat")
        XCTAssertEqual(AnnotationToolType.text.shortcutKey, "t")
        
        XCTAssertEqual(AnnotationToolType.highlight.icon, "highlighter")
        XCTAssertEqual(AnnotationToolType.highlight.shortcutKey, "h")
        
        XCTAssertEqual(AnnotationToolType.underline.icon, "underline")
        XCTAssertEqual(AnnotationToolType.underline.shortcutKey, "u")
        
        XCTAssertEqual(AnnotationToolType.strikeout.icon, "strikethrough")
        XCTAssertEqual(AnnotationToolType.strikeout.shortcutKey, "s")
    }
    
    func testAllToolTypesAreCovered() {
        let allTypes = AnnotationToolType.allCases
        XCTAssertEqual(allTypes.count, 4)
        XCTAssertTrue(allTypes.contains(.text))
        XCTAssertTrue(allTypes.contains(.highlight))
        XCTAssertTrue(allTypes.contains(.underline))
        XCTAssertTrue(allTypes.contains(.strikeout))
    }
}

// MARK: - Annotation View Model Tests

class AnnotationViewModelTests: XCTestCase {
    
    var viewModel: AnnotationViewModel!
    var testPage: PDFPage!
    
    override func setUp() {
        super.setUp()
        viewModel = AnnotationViewModel()
        
        // Create test page
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!
        
        pdfContext.beginPDFPage(nil)
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        let pdfDocument = PDFDocument(data: pdfData as Data)
        testPage = pdfDocument?.page(at: 0)
    }
    
    override func tearDown() {
        viewModel = nil
        testPage = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertNil(viewModel.selectedTool)
        XCTAssertFalse(viewModel.isMarkupMode)
        XCTAssertFalse(viewModel.hasUnsavedAnnotations)
        XCTAssertTrue(viewModel.currentPageAnnotations.isEmpty)
    }
    
    func testToolSelection() {
        viewModel.isMarkupMode = true
        viewModel.selectedTool = .text
        
        XCTAssertEqual(viewModel.selectedTool, .text)
        
        viewModel.selectedTool = .highlight
        XCTAssertEqual(viewModel.selectedTool, .highlight)
    }
    
    func testMarkupModeToggle() {
        viewModel.selectedTool = .text
        viewModel.isMarkupMode = true
        
        XCTAssertNotNil(viewModel.selectedTool)
        
        viewModel.isMarkupMode = false
        XCTAssertNil(viewModel.selectedTool)
    }
    
    func testKeyboardShortcuts() {
        viewModel.isMarkupMode = true
        
        XCTAssertTrue(viewModel.handleKeyboardShortcut("t"))
        XCTAssertEqual(viewModel.selectedTool, .text)
        
        XCTAssertTrue(viewModel.handleKeyboardShortcut("h"))
        XCTAssertEqual(viewModel.selectedTool, .highlight)
        
        XCTAssertTrue(viewModel.handleKeyboardShortcut("u"))
        XCTAssertEqual(viewModel.selectedTool, .underline)
        
        XCTAssertTrue(viewModel.handleKeyboardShortcut("s"))
        XCTAssertEqual(viewModel.selectedTool, .strikeout)
        
        XCTAssertTrue(viewModel.handleKeyboardShortcut("escape"))
        XCTAssertNil(viewModel.selectedTool)
    }
    
    func testKeyboardShortcutsDisabledWhenNotInMarkupMode() {
        viewModel.isMarkupMode = false
        
        XCTAssertFalse(viewModel.handleKeyboardShortcut("t"))
        XCTAssertNil(viewModel.selectedTool)
    }
    
    func testRevertToOriginal() {
        // Add some annotations
        viewModel.currentPageAnnotations = [PDFAnnotation()]
        viewModel.hasUnsavedAnnotations = true
        
        viewModel.revertToOriginal()
        
        XCTAssertTrue(viewModel.currentPageAnnotations.isEmpty)
        XCTAssertFalse(viewModel.hasUnsavedAnnotations)
    }
}

// MARK: - Tool Configuration Tests

class ToolConfigurationTests: XCTestCase {
    
    var configuration: ToolConfiguration!
    
    override func setUp() {
        super.setUp()
        configuration = ToolConfiguration()
    }
    
    override func tearDown() {
        configuration = nil
        super.tearDown()
    }
    
    func testDefaultValues() {
        XCTAssertEqual(configuration.textFont, "Helvetica")
        XCTAssertEqual(configuration.textSize, 14)
        XCTAssertEqual(configuration.textColor, .black)
        XCTAssertEqual(configuration.highlightOpacity, 0.5)
        XCTAssertEqual(configuration.underlineColor, .black)
        XCTAssertEqual(configuration.strikeoutColor, .red)
    }
    
    func testAvailableFonts() {
        let fonts = ToolConfiguration.availableFonts
        XCTAssertTrue(fonts.contains("Helvetica"))
        XCTAssertTrue(fonts.contains("Times New Roman"))
        XCTAssertTrue(fonts.contains("Courier"))
        XCTAssertTrue(fonts.contains("Arial"))
    }
    
    func testTextSizes() {
        let sizes = ToolConfiguration.textSizes
        XCTAssertEqual(sizes.count, 4)
        XCTAssertTrue(sizes.contains(where: { $0.0 == "Small" && $0.1 == 12 }))
        XCTAssertTrue(sizes.contains(where: { $0.0 == "Medium" && $0.1 == 14 }))
        XCTAssertTrue(sizes.contains(where: { $0.0 == "Large" && $0.1 == 18 }))
        XCTAssertTrue(sizes.contains(where: { $0.0 == "Extra Large" && $0.1 == 24 }))
    }
}

#endif