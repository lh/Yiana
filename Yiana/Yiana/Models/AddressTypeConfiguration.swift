//
//  AddressTypeConfiguration.swift
//  Yiana
//
//  Configurable address type system for flexible categorization
//

import Foundation
import SwiftUI

/// Definition of a single address type
struct AddressTypeDefinition: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String              // "Patient", "Client", "Supplier", etc.
    var icon: String             // SF Symbol name
    var colorName: String        // Color identifier
    var allowsMultiple: Bool     // true if multiple addresses of this type can be prime
    var requiresSubtype: Bool    // true if this type requires a subtype name (like specialist name)

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorName: String,
        allowsMultiple: Bool = false,
        requiresSubtype: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.allowsMultiple = allowsMultiple
        self.requiresSubtype = requiresSubtype
    }

    /// Get the SwiftUI Color for this type
    var color: Color {
        switch colorName {
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

/// Configuration for address types
struct AddressTypeConfiguration: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String                          // "Medical Practice", "Business", etc.
    var types: [AddressTypeDefinition]
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        types: [AddressTypeDefinition],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.types = types
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Find a type definition by name
    func type(named: String) -> AddressTypeDefinition? {
        types.first { $0.name.lowercased() == named.lowercased() }
    }

    /// Check if a type name exists
    func hasType(named: String) -> Bool {
        type(named: named) != nil
    }
}

// MARK: - Default Templates

extension AddressTypeConfiguration {
    /// Medical practice template (GP surgery, hospital, etc.)
    static let medicalTemplate = AddressTypeConfiguration(
        name: "Medical Practice",
        types: [
            AddressTypeDefinition(
                name: "Patient",
                icon: "person.fill",
                colorName: "blue",
                allowsMultiple: false,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "GP",
                icon: "cross.fill",
                colorName: "red",
                allowsMultiple: false,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "Optician",
                icon: "eye.fill",
                colorName: "purple",
                allowsMultiple: false,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "Specialist",
                icon: "stethoscope",
                colorName: "green",
                allowsMultiple: true,
                requiresSubtype: true  // Requires specialist name
            )
        ]
    )

    /// Business template (for companies tracking clients, suppliers, etc.)
    static let businessTemplate = AddressTypeConfiguration(
        name: "Business",
        types: [
            AddressTypeDefinition(
                name: "Client",
                icon: "person.2.fill",
                colorName: "blue",
                allowsMultiple: false,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "Supplier",
                icon: "shippingbox.fill",
                colorName: "orange",
                allowsMultiple: true,
                requiresSubtype: true  // Requires company name
            ),
            AddressTypeDefinition(
                name: "Partner",
                icon: "handshake.fill",
                colorName: "green",
                allowsMultiple: true,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "Contractor",
                icon: "hammer.fill",
                colorName: "yellow",
                allowsMultiple: true,
                requiresSubtype: false
            )
        ]
    )

    /// Personal template (for individual use)
    static let personalTemplate = AddressTypeConfiguration(
        name: "Personal",
        types: [
            AddressTypeDefinition(
                name: "Family",
                icon: "house.fill",
                colorName: "pink",
                allowsMultiple: true,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "Friend",
                icon: "person.2.fill",
                colorName: "blue",
                allowsMultiple: true,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "Work",
                icon: "briefcase.fill",
                colorName: "orange",
                allowsMultiple: true,
                requiresSubtype: false
            ),
            AddressTypeDefinition(
                name: "Other",
                icon: "folder.fill",
                colorName: "gray",
                allowsMultiple: true,
                requiresSubtype: false
            )
        ]
    )

    /// All available templates
    static let allTemplates = [
        medicalTemplate,
        businessTemplate,
        personalTemplate
    ]
}

// MARK: - Configuration Manager

/// Manages address type configuration storage and retrieval
@MainActor
class AddressTypeConfigurationManager: ObservableObject {
    static let shared = AddressTypeConfigurationManager()

    @Published var currentConfiguration: AddressTypeConfiguration {
        didSet {
            saveConfiguration()
        }
    }

    private let storageKey = "addressTypeConfiguration"

    private init() {
        // Load saved configuration or use medical template as default
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(AddressTypeConfiguration.self, from: data) {
            self.currentConfiguration = config
        } else {
            self.currentConfiguration = .medicalTemplate
            saveConfiguration()
        }
    }

    /// Save current configuration to UserDefaults
    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(currentConfiguration) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Load a template
    func loadTemplate(_ template: AddressTypeConfiguration) {
        var newConfig = template
        newConfig.id = UUID()
        newConfig.createdAt = Date()
        newConfig.modifiedAt = Date()
        currentConfiguration = newConfig
    }

    /// Export configuration as JSON
    func exportConfiguration() -> Data? {
        try? JSONEncoder().encode(currentConfiguration)
    }

    /// Import configuration from JSON
    func importConfiguration(from data: Data) throws {
        let config = try JSONDecoder().decode(AddressTypeConfiguration.self, from: data)
        currentConfiguration = config
    }

    /// Add a new type
    func addType(_ type: AddressTypeDefinition) {
        currentConfiguration.types.append(type)
        currentConfiguration.modifiedAt = Date()
    }

    /// Update an existing type
    func updateType(_ type: AddressTypeDefinition) {
        if let index = currentConfiguration.types.firstIndex(where: { $0.id == type.id }) {
            currentConfiguration.types[index] = type
            currentConfiguration.modifiedAt = Date()
        }
    }

    /// Remove a type (only if no records use it)
    func removeType(_ type: AddressTypeDefinition, usageCount: Int) throws {
        guard usageCount == 0 else {
            throw ConfigurationError.typeInUse(typeName: type.name, count: usageCount)
        }
        currentConfiguration.types.removeAll { $0.id == type.id }
        currentConfiguration.modifiedAt = Date()
    }

    /// Reorder types
    func moveType(from source: IndexSet, to destination: Int) {
        currentConfiguration.types.move(fromOffsets: source, toOffset: destination)
        currentConfiguration.modifiedAt = Date()
    }
}

// MARK: - Errors

enum ConfigurationError: LocalizedError {
    case typeInUse(typeName: String, count: Int)
    case invalidConfiguration
    case importFailed

    var errorDescription: String? {
        switch self {
        case .typeInUse(let typeName, let count):
            return "Cannot delete '\(typeName)' because \(count) address(es) use this type. Change their type first."
        case .invalidConfiguration:
            return "The configuration file is invalid."
        case .importFailed:
            return "Failed to import configuration."
        }
    }
}
