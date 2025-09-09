//
//  MarkupToolbar.swift
//  Yiana
//
//  SwiftUI toolbar for macOS text markup tools
//  Following the "Digital Paper" paradigm
//

#if os(macOS)
import SwiftUI
import PDFKit

struct MarkupToolbar: View {
    @Binding var selectedTool: AnnotationToolType?
    @Binding var isMarkupMode: Bool
    let onCommit: () -> Void
    let onRevert: () -> Void
    
    @State private var showingCommitConfirmation = false
    @State private var showingRevertConfirmation = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Markup Mode Toggle - more compact
            Toggle(isOn: $isMarkupMode) {
                Label("Markup", systemImage: "pencil.tip.crop.circle")
                    .font(.caption)
            }
            .toggleStyle(.button)
            .help("Toggle markup mode")
            .controlSize(.small)
            
            if isMarkupMode {
                Divider()
                    .frame(height: 20)
                
                // Tool Selection - more compact
                ForEach(AnnotationToolType.allCases, id: \.self) { toolType in
                    Button(action: {
                        selectedTool = (selectedTool == toolType) ? nil : toolType
                    }) {
                        Image(systemName: toolType.icon)
                            .font(.system(size: 14))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(ToolButtonStyle(isSelected: selectedTool == toolType))
                    .keyboardShortcut(KeyEquivalent(toolType.shortcutKey.first!), modifiers: [])
                    .help("\(toolType.rawValue) tool (\(toolType.shortcutKey.uppercased()))")
                    .controlSize(.small)
                }
                
                Spacer()
                
                // Commit and Revert Buttons - more compact
                Button(action: {
                    showingCommitConfirmation = true
                }) {
                    Label("Commit", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .help("Commit annotations to PDF (⌘Return)")
                .controlSize(.small)
                .confirmationDialog(
                    "Commit Annotations?",
                    isPresented: $showingCommitConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Commit", role: .destructive) {
                        onCommit()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently add all annotations to the PDF. This action cannot be undone.")
                }
                
                Button(action: {
                    showingRevertConfirmation = true
                }) {
                    Label("Revert", systemImage: "arrow.uturn.backward.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .help("Revert to today's original (⌘⇧R)")
                .controlSize(.small)
                .confirmationDialog(
                    "Revert to Original?",
                    isPresented: $showingRevertConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Revert", role: .destructive) {
                        onRevert()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will restore the PDF to this morning's version, discarding all changes made today.")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Tool Button Style

struct ToolButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color.accentColor.opacity(0.8)
        } else if isSelected {
            return Color.accentColor
        } else {
            return Color(NSColor.controlColor)
        }
    }
    
    private var borderColor: Color {
        isSelected ? Color.accentColor.opacity(0.8) : Color.clear
    }
}

// MARK: - Preview

struct MarkupToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MarkupToolbar(
                selectedTool: .constant(.text),
                isMarkupMode: .constant(true),
                onCommit: {},
                onRevert: {}
            )
            .padding()
            
            MarkupToolbar(
                selectedTool: .constant(nil),
                isMarkupMode: .constant(false),
                onCommit: {},
                onRevert: {}
            )
            .padding()
        }
        .frame(width: 600)
    }
}

#endif