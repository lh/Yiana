//
//  MarkdownTextEditor.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  SwiftUI wrapper around a platform-native text view that supports Markdown
//  syntax highlighting and a small formatting toolbar. The bridge exposes the
//  underlying selection so higher-level views can trigger formatting actions.
//

import SwiftUI

#if os(iOS)
import UIKit

struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int?
    @Binding var pendingAction: TextPageEditorAction?

    var onEditingBegan: (() -> Void)?
    var onEditingEnded: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .systemBackground
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = false
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.autocapitalizationType = .sentences
        textView.smartDashesType = .yes
        textView.smartQuotesType = .yes
        textView.smartInsertDeleteType = .yes
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        textView.typingAttributes = context.coordinator.baseTypingAttributes
        textView.attributedText = context.coordinator.highlightedAttributedString(for: text)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if context.coordinator.isUpdatingFromCoordinator == false,
           uiView.text != text {
            context.coordinator.isUpdatingFromParent = true
            uiView.attributedText = context.coordinator.highlightedAttributedString(for: text)
            if let cursorPosition {
                uiView.selectedRange = NSRange(location: cursorPosition, length: 0)
            }
            context.coordinator.isUpdatingFromParent = false
        }

        if let action = pendingAction {
            context.coordinator.handle(action: action, on: uiView)
            DispatchQueue.main.async {
                if self.pendingAction == action {
                    self.pendingAction = nil
                }
            }
        }
    }

    /// Coordinator bridges SwiftUI intent (`pendingAction`) with UIKit execution.
    /// It serializes toolbar actions to avoid re-entrant updates that previously
    /// caused "Publishing changes from within view updates" crashes.
    final class Coordinator: NSObject, UITextViewDelegate {
        private(set) var highlighter = MarkdownSyntaxHighlighter()
        var parent: MarkdownTextEditor
        var isUpdatingFromParent = false
        var isUpdatingFromCoordinator = false
        private var isProcessingToolbarAction = false
        private var toolbarActionQueue: [TextPageEditorAction] = []

        var baseTypingAttributes: [NSAttributedString.Key: Any] {
            highlighter.baseTextAttributes()
        }

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onEditingBegan?()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingEnded?()
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromParent else { return }
            isUpdatingFromCoordinator = true
            parent.text = textView.text ?? ""
            parent.cursorPosition = textView.selectedRange.location
            applyHighlight(on: textView)
            isUpdatingFromCoordinator = false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.cursorPosition = textView.selectedRange.location
        }

        func highlightedAttributedString(for text: String) -> NSAttributedString {
            let attributed = NSMutableAttributedString(string: text)
            highlighter.applyHighlighting(to: attributed)
            return attributed
        }

        func applyHighlight(on textView: UITextView) {
            let selectedRange = textView.selectedRange
            let attributed = NSMutableAttributedString(string: textView.text ?? "")
            highlighter.applyHighlighting(to: attributed)
            textView.attributedText = attributed
            textView.selectedRange = selectedRange
            textView.typingAttributes = baseTypingAttributes
        }

        func handle(action: TextPageEditorAction, on textView: UITextView) {
            dispatchPrecondition(condition: .onQueue(.main))

            toolbarActionQueue.append(action)
            #if DEBUG
            if toolbarActionQueue.count > 8 {
                print("⚠️ MarkdownTextEditor queue depth (\(toolbarActionQueue.count)) exceeds expected bounds")
            }
            #endif
            guard !isProcessingToolbarAction else { return }
            processNextToolbarAction(on: textView)
        }

        private func processNextToolbarAction(on textView: UITextView) {
            dispatchPrecondition(condition: .onQueue(.main))
            guard !toolbarActionQueue.isEmpty else { return }
            guard textView.window != nil else {
                toolbarActionQueue.removeAll()
                isProcessingToolbarAction = false
                return
            }

            isProcessingToolbarAction = true
            let next = toolbarActionQueue.removeFirst()

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self else { return }
                guard let textView, textView.window != nil else {
                    self.toolbarActionQueue.removeAll()
                    self.isProcessingToolbarAction = false
                    return
                }

                defer { self.isProcessingToolbarAction = false }
                self.apply(action: next, to: textView)
                self.processNextToolbarAction(on: textView)
            }
        }

        private func apply(action: TextPageEditorAction, to textView: UITextView) {
            isUpdatingFromCoordinator = true
            defer { isUpdatingFromCoordinator = false }

            guard let currentText = textView.text else { return }
            var newText = currentText
            var newCursor = textView.selectedRange

            switch action {
            case .bold:
                let result = wrapSelection(in: currentText, range: newCursor, prefix: "**", suffix: "**")
                newText = result.text
                newCursor = result.cursor
            case .italic:
                let result = wrapSelection(in: currentText, range: newCursor, prefix: "*", suffix: "*")
                newText = result.text
                newCursor = result.cursor
            case .unorderedList:
                let result = toggleList(in: currentText, range: newCursor, markerProvider: { _ in "- " })
                newText = result.text
                newCursor = result.cursor
            case .orderedList:
                let result = toggleList(in: currentText, range: newCursor, markerProvider: { index in "\(index + 1). " })
                newText = result.text
                newCursor = result.cursor
            case .blockquote:
                let result = toggleBlockquote(in: currentText, range: newCursor)
                newText = result.text
                newCursor = result.cursor
            case .horizontalRule:
                let result = insertHorizontalRule(in: currentText, range: newCursor)
                newText = result.text
                newCursor = result.cursor
            case .heading(let level):
                let result = applyHeading(in: currentText, range: newCursor, level: level)
                newText = result.text
                newCursor = result.cursor
            }

            parent.text = newText
            parent.cursorPosition = newCursor.location

            textView.text = newText
            textView.selectedRange = newCursor
            applyHighlight(on: textView)
        }

    }
}

#elseif os(macOS)

import AppKit

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int?
    @Binding var pendingAction: TextPageEditorAction?

    var onEditingBegan: (() -> Void)?
    var onEditingEnded: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 20, height: 16)
        textView.allowsUndo = true
        textView.isRichText = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        context.coordinator.textView = textView
        textView.string = text
        context.coordinator.applyHighlight()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        if !context.coordinator.isUpdatingFromCoordinator,
           textView.string != text {
            context.coordinator.isUpdatingFromParent = true
            textView.string = text
            context.coordinator.applyHighlight()
            if let cursorPosition {
                let location = min(cursorPosition, textView.string.utf16.count)
                textView.selectedRange = NSRange(location: location, length: 0)
            }
            context.coordinator.isUpdatingFromParent = false
        }

        if let action = pendingAction,
           let textView = context.coordinator.textView {
            context.coordinator.apply(action: action)
            DispatchQueue.main.async {
                self.pendingAction = nil
            }
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        let highlighter = MarkdownSyntaxHighlighter()
        weak var textView: NSTextView?
        var isUpdatingFromParent = false
        var isUpdatingFromCoordinator = false

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onEditingBegan?()
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onEditingEnded?()
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromParent,
                  let textView = textView else { return }

            isUpdatingFromCoordinator = true
            parent.text = textView.string
            parent.cursorPosition = textView.selectedRange.location
            applyHighlight()
            isUpdatingFromCoordinator = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.cursorPosition = textView.selectedRange.location
        }

        func applyHighlight() {
            guard let textView = textView else { return }
            let mutable = NSMutableAttributedString(string: textView.string)
            highlighter.applyHighlighting(to: mutable)
            textView.textStorage?.setAttributedString(mutable)
        }

        func apply(action: TextPageEditorAction) {
            guard let textView = textView else { return }
            isUpdatingFromCoordinator = true
            var currentText = textView.string
            var selectedRange = textView.selectedRange

            switch action {
            case .bold:
                let result = wrapSelection(in: currentText, range: selectedRange, prefix: "**", suffix: "**")
                currentText = result.text
                selectedRange = result.cursor
            case .italic:
                let result = wrapSelection(in: currentText, range: selectedRange, prefix: "*", suffix: "*")
                currentText = result.text
                selectedRange = result.cursor
            case .unorderedList:
                let result = toggleList(in: currentText, range: selectedRange, markerProvider: { _ in "- " })
                currentText = result.text
                selectedRange = result.cursor
            case .orderedList:
                let result = toggleList(in: currentText, range: selectedRange, markerProvider: { index in "\(index + 1). " })
                currentText = result.text
                selectedRange = result.cursor
            case .blockquote:
                let result = toggleBlockquote(in: currentText, range: selectedRange)
                currentText = result.text
                selectedRange = result.cursor
            case .horizontalRule:
                let result = insertHorizontalRule(in: currentText, range: selectedRange)
                currentText = result.text
                selectedRange = result.cursor
            case .heading(let level):
                let result = applyHeading(in: currentText, range: selectedRange, level: level)
                currentText = result.text
                selectedRange = result.cursor
            }

            parent.text = currentText
            parent.cursorPosition = selectedRange.location

            textView.string = currentText
            textView.selectedRange = selectedRange
            applyHighlight()
            isUpdatingFromCoordinator = false
        }
    }
}

#endif

#if os(iOS) || os(macOS)

fileprivate let orderedListPrefixRegex = try? NSRegularExpression(pattern: "^\\d+\\.\\s+", options: [])

fileprivate func wrapSelection(in text: String, range: NSRange, prefix: String, suffix: String) -> (text: String, cursor: NSRange) {
    let nsText = text as NSString
    let selectedText = nsText.substring(with: range)
    let replacement: String
    let newLocation: Int

    if range.length > 0 {
        replacement = "\(prefix)\(selectedText)\(suffix)"
        newLocation = range.location + prefix.count + selectedText.count
    } else {
        replacement = "\(prefix)\(suffix)"
        newLocation = range.location + prefix.count
    }

    let newText = nsText.replacingCharacters(in: range, with: replacement)
    let boundedLocation = max(0, min(newLocation, (newText as NSString).length))
    return (newText, NSRange(location: boundedLocation, length: 0))
}

fileprivate func toggleList(
    in text: String,
    range: NSRange,
    markerProvider: (Int) -> String
) -> (text: String, cursor: NSRange) {
    let nsText = text as NSString
    let lineRange = nsText.lineRange(for: range)
    let selectedText = nsText.substring(with: lineRange)

    var lines = selectedText.components(separatedBy: "\n")
    let hadTrailingNewline = lines.last == ""
    if hadTrailingNewline {
        lines.removeLast()
    }

    guard !lines.isEmpty else { return (text, range) }

    let markersApplied = lines.enumerated().allSatisfy { index, line in
        let marker = markerProvider(index)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        if marker.contains(".") {
            return orderedListPrefixRegex?.firstMatch(
                in: trimmed,
                options: [],
                range: NSRange(location: 0, length: trimmed.utf16.count)
            ) != nil
        } else {
            let trimmedMarker = marker.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix(trimmedMarker)
        }
    }

    let updatedLines: [String] = lines.enumerated().map { index, line in
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        let indentationString = String(indentation)
        var remainder = String(line.dropFirst(indentation.count))
        let marker = markerProvider(index)
        let trimmedMarker = marker.trimmingCharacters(in: .whitespaces)
        let trimmedRemainder = remainder.trimmingCharacters(in: .whitespaces)

        guard !trimmedRemainder.isEmpty else { return String(line) }

        if markersApplied {
            if marker.contains(".") {
                if let match = orderedListPrefixRegex?.firstMatch(
                    in: trimmedRemainder,
                    options: [],
                    range: NSRange(location: 0, length: trimmedRemainder.utf16.count)
                ) {
                    var mutable = trimmedRemainder
                    let start = mutable.index(mutable.startIndex, offsetBy: match.range.length)
                    mutable = String(mutable[start...]).trimmingCharacters(in: .whitespaces)
                    return indentationString + mutable
                }
                return String(line)
            }

            if remainder.hasPrefix(trimmedMarker) {
                remainder.removeFirst(trimmedMarker.count)
                let trimmed = remainder.drop { $0 == " " }
                return indentationString + String(trimmed)
            }
            return String(line)
        } else {
            let content = trimmedRemainder
            return indentationString + markerProvider(index) + content
        }
    }

    var replacement = updatedLines.joined(separator: "\n")
    if hadTrailingNewline {
        replacement.append("\n")
    }

    let newText = nsText.replacingCharacters(in: lineRange, with: replacement)
    let location = min(lineRange.location + replacement.count, (newText as NSString).length)
    return (newText, NSRange(location: location, length: 0))
}

fileprivate func toggleBlockquote(in text: String, range: NSRange) -> (text: String, cursor: NSRange) {
    let nsText = text as NSString
    let lineRange = nsText.lineRange(for: range)
    let selectedText = nsText.substring(with: lineRange)

    var lines = selectedText.components(separatedBy: "\n")
    let hadTrailingNewline = lines.last == ""
    if hadTrailingNewline { lines.removeLast() }

    guard !lines.isEmpty else { return (text, range) }

    let markersApplied = lines.allSatisfy { line in
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    let updatedLines = lines.map { line -> String in
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        let indentationString = String(indentation)
        var remainder = String(line.dropFirst(indentation.count))
        let trimmed = remainder.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return String(line) }

        if markersApplied {
            if remainder.hasPrefix("> ") {
                remainder.removeFirst(2)
            } else if remainder.hasPrefix(">") {
                remainder.removeFirst()
                if remainder.first == " " { remainder.removeFirst() }
            }
            return indentationString + remainder
        } else {
            return indentationString + "> " + trimmed
        }
    }

    var replacement = updatedLines.joined(separator: "\n")
    if hadTrailingNewline { replacement.append("\n") }

    let newText = nsText.replacingCharacters(in: lineRange, with: replacement)
    let location = min(lineRange.location, (newText as NSString).length)
    return (newText, NSRange(location: location, length: 0))
}

fileprivate func insertHorizontalRule(in text: String, range: NSRange) -> (text: String, cursor: NSRange) {
    let nsText = text as NSString
    let insertion = "\n\n---\n\n"
    let newText = nsText.replacingCharacters(in: range, with: insertion)
    let location = min(range.location + insertion.count, (newText as NSString).length)
    return (newText, NSRange(location: location, length: 0))
}

fileprivate func applyHeading(in text: String, range: NSRange, level: Int) -> (text: String, cursor: NSRange) {
    let nsText = text as NSString
    let lineRange = nsText.lineRange(for: range)
    let selectedText = nsText.substring(with: lineRange)

    var lines = selectedText.components(separatedBy: "\n")
    let hadTrailingNewline = lines.last == ""
    if hadTrailingNewline { lines.removeLast() }

    guard !lines.isEmpty else { return (text, range) }

    let marker = String(repeating: "#", count: max(1, min(level, 3))) + " "

    let updatedLines = lines.map { line -> String in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return String(line) }

        let withoutHashes = trimmed.drop { $0 == "#" }
        let stripped = withoutHashes.drop { $0 == " " }
        return marker + String(stripped)
    }

    var replacement = updatedLines.joined(separator: "\n")
    if hadTrailingNewline { replacement.append("\n") }

    let newText = nsText.replacingCharacters(in: lineRange, with: replacement)
    let location = min(lineRange.location + marker.count, (newText as NSString).length)
    return (newText, NSRange(location: location, length: 0))
}

#endif
