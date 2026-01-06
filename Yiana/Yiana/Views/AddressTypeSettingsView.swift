//
//  AddressTypeSettingsView.swift
//  Yiana
//
//  Settings view for managing address type configuration
//

import SwiftUI

struct AddressTypeSettingsView: View {
    @StateObject private var configManager = AddressTypeConfigurationManager.shared
    @State private var showingTemplatePicker = false
    @State private var showingTypeEditor = false
    @State private var showingImportPicker = false
    @State private var editingType: AddressTypeDefinition?
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Current Configuration")
                        .font(.headline)
                    Spacer()
                    Text(configManager.currentConfiguration.name)
                        .foregroundColor(.secondary)
                }

                Button {
                    showingTemplatePicker = true
                } label: {
                    Label("Load Template", systemImage: "doc.on.doc")
                }
            }

            Section("Address Types") {
                ForEach(configManager.currentConfiguration.types) { type in
                    AddressTypeRow(type: type) {
                        editingType = type
                        showingTypeEditor = true
                    }
                }
                .onMove { source, destination in
                    configManager.moveType(from: source, to: destination)
                }
                .onDelete { indexSet in
                    deleteTypes(at: indexSet)
                }

                Button {
                    editingType = nil
                    showingTypeEditor = true
                } label: {
                    Label("Add Type", systemImage: "plus.circle")
                }
            }

            Section("Import/Export") {
                Button {
                    exportConfiguration()
                } label: {
                    Label("Export Configuration", systemImage: "square.and.arrow.up")
                }

                Button {
                    showingImportPicker = true
                } label: {
                    Label("Import Configuration", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle("Address Types")
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerView(configManager: configManager)
        }
        .sheet(isPresented: $showingTypeEditor) {
            AddressTypeEditorView(
                type: editingType,
                onSave: { type in
                    if editingType != nil {
                        configManager.updateType(type)
                    } else {
                        configManager.addType(type)
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func deleteTypes(at indexSet: IndexSet) {
        for index in indexSet {
            let type = configManager.currentConfiguration.types[index]
            let usageCount = 0
            do {
                try configManager.removeType(type, usageCount: usageCount)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func exportConfiguration() {
        guard let data = configManager.exportConfiguration() else {
            errorMessage = "Failed to export configuration"
            showingError = true
            return
        }

        let fileName = "\(configManager.currentConfiguration.name).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            #if os(iOS)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            #elseif os(macOS)
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = fileName
            savePanel.allowedContentTypes = [.json]
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    try? data.write(to: url)
                }
            }
            #endif
        } catch {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                throw ConfigurationError.importFailed
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            try configManager.importConfiguration(from: data)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Address Type Row

struct AddressTypeRow: View {
    let type: AddressTypeDefinition
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.name)
                        .font(.body)
                    HStack(spacing: 12) {
                        if type.requiresSubtype {
                            Text("Requires name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if type.allowsMultiple {
                            Text("Multiple prime")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Picker

struct TemplatePickerView: View {
    @ObservedObject var configManager: AddressTypeConfigurationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(AddressTypeConfiguration.allTemplates) { template in
                Button {
                    configManager.loadTemplate(template)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.name)
                            .font(.headline)

                        HStack(spacing: 4) {
                            ForEach(template.types) { type in
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                            }
                        }

                        Text("\(template.types.count) types")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Choose Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Type Editor

struct AddressTypeEditorView: View {
    let type: AddressTypeDefinition?
    let onSave: (AddressTypeDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var icon: String
    @State private var colorName: String
    @State private var allowsMultiple: Bool
    @State private var requiresSubtype: Bool

    init(type: AddressTypeDefinition?, onSave: @escaping (AddressTypeDefinition) -> Void) {
        self.type = type
        self.onSave = onSave

        _name = State(initialValue: type?.name ?? "")
        _icon = State(initialValue: type?.icon ?? "folder.fill")
        _colorName = State(initialValue: type?.colorName ?? "blue")
        _allowsMultiple = State(initialValue: type?.allowsMultiple ?? false)
        _requiresSubtype = State(initialValue: type?.requiresSubtype ?? false)
    }

    private let availableIcons = [
        "person.fill", "person.2.fill", "house.fill", "building.2.fill",
        "cross.fill", "stethoscope", "eye.fill", "phone.fill",
        "envelope.fill", "briefcase.fill", "shippingbox.fill", "hammer.fill",
        "handshake.fill", "folder.fill", "star.fill", "heart.fill"
    ]

    private let availableColors = [
        "blue", "red", "green", "orange", "purple", "pink",
        "yellow", "teal", "indigo", "cyan", "gray"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Type Information") {
                    TextField("Name", text: $name)

                    Picker("Icon", selection: $icon) {
                        ForEach(availableIcons, id: \.self) { iconName in
                            Label {
                                Text(iconName)
                            } icon: {
                                Image(systemName: iconName)
                            }
                            .tag(iconName)
                        }
                    }

                    Picker("Color", selection: $colorName) {
                        ForEach(availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(colorForName(color))
                                    .frame(width: 20, height: 20)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                }

                Section("Behavior") {
                    Toggle("Allow multiple prime addresses", isOn: $allowsMultiple)

                    Toggle("Require subtype name", isOn: $requiresSubtype)
                }

                Section("Preview") {
                    HStack {
                        Image(systemName: icon)
                            .foregroundColor(colorForName(colorName))
                            .frame(width: 30)
                        Text(name.isEmpty ? "Type Name" : name)
                    }
                }
            }
            .navigationTitle(type == nil ? "New Type" : "Edit Type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newType = AddressTypeDefinition(
                            id: type?.id ?? UUID(),
                            name: name,
                            icon: icon,
                            colorName: colorName,
                            allowsMultiple: allowsMultiple,
                            requiresSubtype: requiresSubtype
                        )
                        onSave(newType)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "cyan": return .cyan
        default: return .gray
        }
    }
}

#Preview {
    NavigationView {
        AddressTypeSettingsView()
    }
}
