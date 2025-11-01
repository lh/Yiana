//
//  AddressesView.swift
//  Yiana
//
//  Displays extracted addresses for a document with inline editing
//

import SwiftUI

struct AddressesView: View {
    let documentId: String
    @StateObject private var repository = AddressRepository()
    @State private var addresses: [ExtractedAddress] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTrigger = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView("Loading addresses...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if addresses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No addresses extracted yet")
                        .font(.headline)
                    Text("Addresses will appear here after OCR processing completes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(addresses, id: \.id) { address in
                            AddressCard(address: address, onSave: {
                                refreshTrigger.toggle()
                            })
                        }
                    }
                }
            }
        }
        .task {
            await loadAddresses()
        }
        .onChange(of: refreshTrigger) {
            Task {
                await loadAddresses()
            }
        }
    }

    private func loadAddresses() async {
        isLoading = true
        errorMessage = nil

        do {
            addresses = try await repository.addresses(forDocument: documentId)
            isLoading = false
        } catch {
            errorMessage = "Failed to load addresses: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Address Card
struct AddressCard: View {
    let address: ExtractedAddress
    let onSave: () -> Void
    
    @State private var isEditing = false
    @StateObject private var repository = AddressRepository()

    // Editable fields
    @State private var fullName: String
    @State private var dateOfBirth: String
    @State private var addressLine1: String
    @State private var addressLine2: String
    @State private var city: String
    @State private var county: String
    @State private var postcode: String
    @State private var phoneHome: String
    @State private var phoneWork: String
    @State private var phoneMobile: String
    @State private var gpName: String
    @State private var gpPractice: String
    @State private var gpAddress: String
    @State private var gpPostcode: String

    @State private var isSaving = false

    init(address: ExtractedAddress, onSave: @escaping () -> Void) {
        self.address = address
        self.onSave = onSave
        _fullName = State(initialValue: address.fullName ?? "")
        _dateOfBirth = State(initialValue: address.dateOfBirth ?? "")
        _addressLine1 = State(initialValue: address.addressLine1 ?? "")
        _addressLine2 = State(initialValue: address.addressLine2 ?? "")
        _city = State(initialValue: address.city ?? "")
        _county = State(initialValue: address.county ?? "")
        _postcode = State(initialValue: address.postcode ?? "")
        _phoneHome = State(initialValue: address.phoneHome ?? "")
        _phoneWork = State(initialValue: address.phoneWork ?? "")
        _phoneMobile = State(initialValue: address.phoneMobile ?? "")
        _gpName = State(initialValue: address.gpName ?? "")
        _gpPractice = State(initialValue: address.gpPractice ?? "")
        _gpAddress = State(initialValue: address.gpAddress ?? "")
        _gpPostcode = State(initialValue: address.gpPostcode ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if address.hasPatientInfo {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    Text("Patient Information")
                        .font(.headline)
                } else if address.hasGPInfo {
                    Image(systemName: "cross.fill")
                        .foregroundColor(.red)
                    Text("GP Information")
                        .font(.headline)
                }
                Spacer()

                // Edit/Save/Cancel buttons
                if isEditing {
                    Button("Cancel") {
                        resetFields()
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                } else {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }

                if let pageNum = address.pageNumber {
                    Text("Page \(pageNum)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Patient Information
            if address.hasPatientInfo {
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing {
                        EditableField(label: "Name", text: $fullName, icon: "person")
                        EditableField(label: "Date of Birth", text: $dateOfBirth, icon: "calendar")
                        EditableField(label: "Address Line 1", text: $addressLine1, icon: "house")
                        EditableField(label: "Address Line 2", text: $addressLine2, icon: "house")
                        EditableField(label: "City", text: $city, icon: "building.2")
                        EditableField(label: "County", text: $county, icon: "map")
                        EditableField(label: "Postcode", text: $postcode, icon: "mappin.circle")
                        EditableField(label: "Home Phone", text: $phoneHome, icon: "phone")
                        EditableField(label: "Work Phone", text: $phoneWork, icon: "phone")
                        EditableField(label: "Mobile Phone", text: $phoneMobile, icon: "phone")
                    } else {
                        if !fullName.isEmpty {
                            AddressInfoRow(label: "Name", value: fullName, icon: "person")
                        }
                        if !dateOfBirth.isEmpty {
                            AddressInfoRow(label: "Date of Birth", value: dateOfBirth, icon: "calendar")
                        }
                        if let formattedAddress = address.formattedPatientAddress {
                            AddressInfoRow(label: "Address", value: formattedAddress, icon: "house")
                        }
                        if !postcode.isEmpty {
                            PostcodeRow(postcode: postcode, isValid: address.postcodeValid)
                        }
                        if let phones = address.formattedPhones {
                            AddressInfoRow(label: "Phone", value: phones, icon: "phone")
                        }
                    }
                }
            }

            // GP Information
            if address.hasGPInfo {
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing {
                        EditableField(label: "GP Name", text: $gpName, icon: "stethoscope")
                        EditableField(label: "Practice", text: $gpPractice, icon: "building.2")
                        EditableField(label: "GP Address", text: $gpAddress, icon: "house")
                        EditableField(label: "GP Postcode", text: $gpPostcode, icon: "mappin.circle")
                    } else {
                        if !gpName.isEmpty {
                            AddressInfoRow(label: "GP Name", value: gpName, icon: "stethoscope")
                        }
                        if !gpPractice.isEmpty {
                            AddressInfoRow(label: "Practice", value: gpPractice, icon: "building.2")
                        }
                        if !gpAddress.isEmpty {
                            AddressInfoRow(label: "Address", value: gpAddress, icon: "house")
                        }
                        if !gpPostcode.isEmpty {
                            AddressInfoRow(label: "Postcode", value: gpPostcode, icon: "mappin.circle")
                        }
                        if let odsCode = address.gpOdsCode {
                            AddressInfoRow(label: "ODS Code", value: odsCode, icon: "number")
                        }
                    }
                }
            }

            // Metadata
            if !isEditing, let confidence = address.extractionConfidence {
                HStack {
                    Text("Confidence:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(confidenceColor(confidence))
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func resetFields() {
        fullName = address.fullName ?? ""
        dateOfBirth = address.dateOfBirth ?? ""
        addressLine1 = address.addressLine1 ?? ""
        addressLine2 = address.addressLine2 ?? ""
        city = address.city ?? ""
        county = address.county ?? ""
        postcode = address.postcode ?? ""
        phoneHome = address.phoneHome ?? ""
        phoneWork = address.phoneWork ?? ""
        phoneMobile = address.phoneMobile ?? ""
        gpName = address.gpName ?? ""
        gpPractice = address.gpPractice ?? ""
        gpAddress = address.gpAddress ?? ""
        gpPostcode = address.gpPostcode ?? ""
    }

    private func saveChanges() async {
        isSaving = true

        var updatedAddress = address
        // Save empty strings as empty strings (not nil) so cleared fields stay cleared
        // Empty string means "user explicitly cleared this field"
        updatedAddress.fullName = fullName.isEmpty ? "" : fullName
        updatedAddress.dateOfBirth = dateOfBirth.isEmpty ? "" : dateOfBirth
        updatedAddress.addressLine1 = addressLine1.isEmpty ? "" : addressLine1
        updatedAddress.addressLine2 = addressLine2.isEmpty ? "" : addressLine2
        updatedAddress.city = city.isEmpty ? "" : city
        updatedAddress.county = county.isEmpty ? "" : county
        updatedAddress.postcode = postcode.isEmpty ? "" : postcode
        updatedAddress.phoneHome = phoneHome.isEmpty ? "" : phoneHome
        updatedAddress.phoneWork = phoneWork.isEmpty ? "" : phoneWork
        updatedAddress.phoneMobile = phoneMobile.isEmpty ? "" : phoneMobile
        updatedAddress.gpName = gpName.isEmpty ? "" : gpName
        updatedAddress.gpPractice = gpPractice.isEmpty ? "" : gpPractice
        updatedAddress.gpAddress = gpAddress.isEmpty ? "" : gpAddress
        updatedAddress.gpPostcode = gpPostcode.isEmpty ? "" : gpPostcode

        do {
            try await repository.saveOverride(
                originalId: address.id!,
                updatedAddress: updatedAddress,
                reason: "corrected"
            )
            isEditing = false
            onSave() // Trigger refresh
        } catch {
            // Handle error silently for now
            print("Failed to save: \(error)")
        }

        isSaving = false
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Info Row
private struct AddressInfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
        }
    }
}

// MARK: - Editable Field
private struct EditableField: View {
    let label: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(label, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Postcode Row
private struct PostcodeRow: View {
    let postcode: String
    let isValid: Bool?

    var body: some View {
        HStack {
            AddressInfoRow(label: "Postcode", value: postcode, icon: "mappin.circle")
            if isValid == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AddressesView(documentId: "test_document")
}
