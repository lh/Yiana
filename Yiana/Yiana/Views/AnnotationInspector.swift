//
//  AnnotationInspector.swift
//  Yiana
//
//  SwiftUI inspector panel for configuring annotation tools
//  Following the "Digital Paper" paradigm - like choosing your pen before writing
//

#if os(macOS)
import SwiftUI
import AppKit

struct AnnotationInspector: View {
    @Binding var selectedTool: AnnotationToolType?
    @ObservedObject var toolConfiguration: ToolConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tool Settings")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let tool = selectedTool {
                switch tool {
                case .text:
                    TextToolInspector(configuration: toolConfiguration)
                case .highlight:
                    HighlightToolInspector(configuration: toolConfiguration)
                case .underline:
                    UnderlineToolInspector(configuration: toolConfiguration)
                case .strikeout:
                    StrikeoutToolInspector(configuration: toolConfiguration)
                }
            } else {
                Text("Select a tool to configure")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 250)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Tool Configuration Model

class ToolConfiguration: ObservableObject {
    // Text Tool Settings
    @Published var textFont: String = "Helvetica"
    @Published var textSize: CGFloat = 14
    @Published var textColor: Color = .black
    
    // Highlight Tool Settings
    @Published var highlightColor: Color = Color.yellow.opacity(0.5)
    @Published var highlightOpacity: Double = 0.5
    
    // Underline Tool Settings
    @Published var underlineColor: Color = .black
    @Published var underlineThickness: CGFloat = 1.0
    
    // Strikeout Tool Settings
    @Published var strikeoutColor: Color = .red
    @Published var strikeoutThickness: CGFloat = 1.0
    
    // Available fonts - limited selection for "choosing your pen" metaphor
    static let availableFonts = [
        "Helvetica",
        "Times New Roman",
        "Courier",
        "Arial"
    ]
    
    // Available colors - like pen colors
    static let availableColors: [Color] = [
        .black,
        .blue,
        .red,
        .green,
        .orange,
        .purple
    ]
    
    // Text sizes - simple options
    static let textSizes: [(String, CGFloat)] = [
        ("Small", 12),
        ("Medium", 14),
        ("Large", 18),
        ("Extra Large", 24)
    ]
}

// MARK: - Text Tool Inspector

struct TextToolInspector: View {
    @ObservedObject var configuration: ToolConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Font Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Font")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $configuration.textFont) {
                    ForEach(ToolConfiguration.availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Size Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $configuration.textSize) {
                    ForEach(ToolConfiguration.textSizes, id: \.1) { name, size in
                        Text(name).tag(size)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Color Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(ToolConfiguration.availableColors, id: \.self) { color in
                        ColorButton(
                            color: color,
                            isSelected: configuration.textColor == color,
                            action: { configuration.textColor = color }
                        )
                    }
                }
            }
            
            // Preview
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Sample Text")
                    .font(.custom(configuration.textFont, size: configuration.textSize))
                    .foregroundColor(configuration.textColor)
                    .padding(8)
                    .background(Color.white)
                    .border(Color.gray.opacity(0.3))
            }
        }
    }
}

// MARK: - Highlight Tool Inspector

struct HighlightToolInspector: View {
    @ObservedObject var configuration: ToolConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Highlight Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ColorButton(color: .yellow, isSelected: configuration.highlightColor == Color.yellow.opacity(configuration.highlightOpacity)) {
                        configuration.highlightColor = Color.yellow.opacity(configuration.highlightOpacity)
                    }
                    ColorButton(color: .pink, isSelected: configuration.highlightColor == Color.pink.opacity(configuration.highlightOpacity)) {
                        configuration.highlightColor = Color.pink.opacity(configuration.highlightOpacity)
                    }
                    ColorButton(color: .green, isSelected: configuration.highlightColor == Color.green.opacity(configuration.highlightOpacity)) {
                        configuration.highlightColor = Color.green.opacity(configuration.highlightOpacity)
                    }
                    ColorButton(color: .blue, isSelected: configuration.highlightColor == Color.blue.opacity(configuration.highlightOpacity)) {
                        configuration.highlightColor = Color.blue.opacity(configuration.highlightOpacity)
                    }
                }
            }
            
            // Opacity Slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Opacity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $configuration.highlightOpacity, in: 0.2...0.8)
            }
            
            // Preview
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Highlighted Text")
                    .padding(8)
                    .background(configuration.highlightColor)
                    .background(Color.white)
            }
        }
    }
}

// MARK: - Underline Tool Inspector

struct UnderlineToolInspector: View {
    @ObservedObject var configuration: ToolConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Underline Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach([Color.black, Color.blue, Color.red], id: \.self) { color in
                        ColorButton(
                            color: color,
                            isSelected: configuration.underlineColor == color,
                            action: { configuration.underlineColor = color }
                        )
                    }
                }
            }
            
            // Preview
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Underlined Text")
                    .underline(color: configuration.underlineColor)
                    .padding(8)
                    .background(Color.white)
                    .border(Color.gray.opacity(0.3))
            }
        }
    }
}

// MARK: - Strikeout Tool Inspector

struct StrikeoutToolInspector: View {
    @ObservedObject var configuration: ToolConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Strikeout Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach([Color.red, Color.black, Color.blue], id: \.self) { color in
                        ColorButton(
                            color: color,
                            isSelected: configuration.strikeoutColor == color,
                            action: { configuration.strikeoutColor = color }
                        )
                    }
                }
            }
            
            // Preview
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Strikethrough Text")
                    .strikethrough(color: configuration.strikeoutColor)
                    .padding(8)
                    .background(Color.white)
                    .border(Color.gray.opacity(0.3))
            }
        }
    }
}

// MARK: - Color Button Component

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct AnnotationInspector_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            AnnotationInspector(
                selectedTool: .constant(.text),
                toolConfiguration: ToolConfiguration()
            )
            
            AnnotationInspector(
                selectedTool: .constant(.highlight),
                toolConfiguration: ToolConfiguration()
            )
        }
    }
}

#endif