//
//  AddressesView.swift
//  Yiana
//
//  Displays extracted addresses for a document with inline editing
//

import SwiftUI
import YianaExtraction

struct AddressesView: View {
    let documentId: String
    @StateObject private var repository = AddressRepository()
    @State private var addresses: [ExtractedAddress] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTrigger = false

    // Sort addresses by type (Patient, GP, Optician, Specialist), then by specialist name if applicable
    private var sortedAddresses: [ExtractedAddress] {
        addresses.sorted { addr1, addr2 in
            // First sort by type order
            if addr1.typeSortOrder != addr2.typeSortOrder {
                return addr1.typeSortOrder < addr2.typeSortOrder
            }
            // For specialists, sort alphabetically by specialist name
            if addr1.typedAddressType == .specialist && addr2.typedAddressType == .specialist {
                let name1 = addr1.specialistName ?? ""
                let name2 = addr2.specialistName ?? ""
                return name1 < name2
            }
            // Otherwise maintain order
            return false
        }
    }

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
                        // Prime addresses first
                        let primeAddresses = sortedAddresses.filter { $0.isPrime == true }
                        let nonPrimeAddresses = sortedAddresses.filter { $0.isPrime != true }

                        ForEach(primeAddresses, id: \.stableId) { address in
                            AddressCard(
                                address: address,
                                documentId: documentId,
                                onSave: {
                                    refreshTrigger.toggle()
                                }
                            )
                        }

                        // Divider between prime and non-prime
                        if !primeAddresses.isEmpty && !nonPrimeAddresses.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                        }

                        ForEach(nonPrimeAddresses, id: \.stableId) { address in
                            AddressCard(
                                address: address,
                                documentId: documentId,
                                onSave: {
                                    refreshTrigger.toggle()
                                }
                            )
                        }
                    }
                }
            }

            // Add Address button
            addAddressMenu
        }
        .task {
            await loadAddresses()
        }
        .onAppear {
            Task { await loadAddresses() }
        }
        .onChange(of: refreshTrigger) {
            Task {
                await loadAddresses()
            }
        }
    }

    private var addAddressMenu: some View {
        Menu {
            Button("Patient") { Task { await addAddress(type: "patient") } }
            Button("GP") { Task { await addAddress(type: "gp") } }
            Button("Optician") { Task { await addAddress(type: "optician") } }
            Button("Other") { Task { await addAddress(type: "specialist") } }
        } label: {
            Label("Add Address", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func addAddress(type: String) async {
        do {
            try await repository.addManualAddress(documentId: documentId, addressType: type)
            refreshTrigger.toggle()
        } catch {
            errorMessage = "Failed to add address: \(error.localizedDescription)"
        }
    }

    private func loadAddresses() async {
        isLoading = true
        errorMessage = nil

        do {
            addresses = try await repository.addresses(forDocument: documentId)
            isLoading = false

            // Lazy-ingest into entity database for pre-deployment documents
            let capturedDocId = documentId
            Task.detached {
                EntityDatabaseService.shared.ingestDocument(capturedDocId)
            }
        } catch {
            errorMessage = "Failed to load addresses: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Address Card
struct AddressCard: View {
    let address: ExtractedAddress
    let documentId: String
    let onSave: () -> Void

    @State private var isEditingPatient = false
    @StateObject private var repository = AddressRepository()
    @StateObject private var configManager = AddressTypeConfigurationManager.shared

    // Editable fields
    @State private var fullName: String
    @State private var title: String
    @State private var firstName: String
    @State private var surname: String
    @State private var dateOfBirth: String
    @State private var mrn: String
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

    @State private var isSavingPatient = false
    @State private var patientCopied = false

    // Prime address system
    @State private var selectedType: String
    @State private var isPrime: Bool
    @State private var subtypeName: String
    @State private var showingSubtypeNameInput = false

    init(address: ExtractedAddress, documentId: String, onSave: @escaping () -> Void) {
        self.address = address
        self.documentId = documentId
        self.onSave = onSave
        _fullName = State(initialValue: address.fullName ?? "")
        _title = State(initialValue: address.title ?? "")
        _firstName = State(initialValue: address.firstname ?? "")
        _surname = State(initialValue: address.surname ?? "")
        _dateOfBirth = State(initialValue: address.dateOfBirth ?? "")
        _mrn = State(initialValue: address.mrn ?? "")
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
        _selectedType = State(initialValue: address.addressType ?? "patient")
        _isPrime = State(initialValue: address.isPrime ?? false)
        _subtypeName = State(initialValue: address.specialistName ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with type/prime controls
            VStack(spacing: 8) {
                HStack {
                    // Quick dismiss/delete for non-prime cards
                    if !isPrime && !isEditingPatient {
                        if address.pageNumber == 0 {
                            Button {
                                Task { await deleteManualAddress() }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete this address")
                        } else {
                            Button {
                                Task { await dismissAddress() }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Dismiss this address")
                        }
                    }

                    Image(systemName: currentTypeDefinition?.icon ?? "folder.fill")
                        .foregroundColor(isPrime ? (currentTypeDefinition?.color ?? .gray) : .secondary)
                    Text(addressTypeLabel)
                        .font(.headline)
                        .foregroundColor(isPrime ? .primary : .secondary)
                    Spacer()

                    // Page number
                    if let pageNum = address.pageNumber {
                        Text("Page \(pageNum)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Type and Prime controls
                HStack {
                    // Type selector (only shown in edit mode)
                    if isEditingPatient {
                        Picker("Type", selection: $selectedType) {
                            ForEach(configManager.currentConfiguration.types) { typeDef in
                                Text(typeDef.name).tag(typeDef.key)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if isEditingPatient {
                        Spacer()

                        // Prime toggle
                        Toggle("Prime", isOn: $isPrime)
                            .toggleStyle(.switch)
                    }
                }
                .font(.caption)

                HStack {
                    Spacer()

                    // Copy/Share button (platform-specific, not when editing)
                    #if os(macOS)
                    if !isEditingPatient {
                        Button {
                            copyAddress()
                        } label: {
                            Label(patientCopied ? "Copied" : "Copy",
                                  systemImage: patientCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(patientCopied ? .green : .blue)
                        .help("Copy address to clipboard")
                    }
                    #elseif os(iOS)
                    if !isEditingPatient {
                        ShareLink(item: formattedAddress) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                    }
                    #endif

                    // Edit/Save/Cancel buttons
                    if isEditingPatient {
                        // Delete (page 0) or Dismiss (extracted) button
                        if address.pageNumber == 0 {
                            Button(role: .destructive) {
                                Task { await deleteManualAddress() }
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(role: .destructive) {
                                Task { await dismissAddress() }
                            } label: {
                                Label("Dismiss", systemImage: "eye.slash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Cancel") {
                            resetFields()
                            isEditingPatient = false
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)

                        Button("Save") {
                            Task {
                                await saveChanges()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSavingPatient)
                        .keyboardShortcut(.return, modifiers: [])
                    } else {
                        Button {
                            isEditingPatient = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
            }

            Divider()

            // Fields based on address type (use selectedType during editing)
            VStack(alignment: .leading, spacing: 8) {
                if (isEditingPatient ? selectedType : address.addressType ?? "patient") == "gp" {
                    // GP fields
                    if isEditingPatient {
                        EditableField(label: "GP Name", text: $gpName, icon: "stethoscope", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Practice", text: $gpPractice, icon: "building.2", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Address", text: $gpAddress, icon: "house", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Postcode", text: $gpPostcode, icon: "mappin.circle", onSubmit: { Task { await saveChanges() } }, isPostcode: true)
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
                        nhsCandidatesView
                    }
                } else if (isEditingPatient ? selectedType : address.addressType ?? "patient") == "patient" {
                    // Patient fields
                    if isEditingPatient {
                        EditableField(label: "MRN", text: $mrn, icon: "number", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Title", text: $title, icon: "person", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "First name(s)", text: $firstName, icon: "person", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Surname", text: $surname, icon: "person", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Date of Birth", text: $dateOfBirth, icon: "calendar", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Address Line 1", text: $addressLine1, icon: "house", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Address Line 2", text: $addressLine2, icon: "house", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "City", text: $city, icon: "building.2", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "County", text: $county, icon: "map", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Postcode", text: $postcode, icon: "mappin.circle", onSubmit: { Task { await saveChanges() } }, isPostcode: true)
                        EditableField(label: "Home Phone", text: $phoneHome, icon: "phone", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Work Phone", text: $phoneWork, icon: "phone", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Mobile Phone", text: $phoneMobile, icon: "phone", onSubmit: { Task { await saveChanges() } })
                    } else {
                        if !fullName.isEmpty {
                            AddressInfoRow(label: "Name", value: fullName, icon: "person")
                        }
                        if !mrn.isEmpty {
                            AddressInfoRow(label: "MRN", value: mrn, icon: "number")
                        }
                        if !dateOfBirth.isEmpty {
                            AddressInfoRow(label: "Date of Birth", value: dateOfBirth, icon: "calendar")
                        }
                        if let formattedAddr = address.formattedPatientAddress {
                            AddressInfoRow(label: "Address", value: formattedAddr, icon: "house")
                        }
                        if !postcode.isEmpty {
                            PostcodeRow(postcode: postcode, isValid: address.postcodeValid)
                        }
                        if let phones = address.formattedPhones {
                            AddressInfoRow(label: "Phone", value: phones, icon: "phone")
                        }
                    }
                } else {
                    // Optician/Specialist fields — name, address, postcode, phone (no DOB)
                    if isEditingPatient {
                        EditableField(label: "Name", text: $fullName, icon: "building.2", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Address Line 1", text: $addressLine1, icon: "house", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Address Line 2", text: $addressLine2, icon: "house", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "City", text: $city, icon: "building.2", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "County", text: $county, icon: "map", onSubmit: { Task { await saveChanges() } })
                        EditableField(label: "Postcode", text: $postcode, icon: "mappin.circle", onSubmit: { Task { await saveChanges() } }, isPostcode: true)
                        EditableField(label: "Phone", text: $phoneHome, icon: "phone", onSubmit: { Task { await saveChanges() } })
                    } else {
                        if !fullName.isEmpty {
                            AddressInfoRow(label: "Name", value: fullName, icon: "building.2")
                        }
                        if let formattedAddr = address.formattedPatientAddress {
                            AddressInfoRow(label: "Address", value: formattedAddr, icon: "house")
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

            // Metadata
            if !isEditingPatient, let confidence = address.extractionConfidence {
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
        title = address.title ?? ""
        firstName = address.firstname ?? ""
        surname = address.surname ?? ""
        dateOfBirth = address.dateOfBirth ?? ""
        mrn = address.mrn ?? ""
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
        isSavingPatient = true

        var updatedAddress = address

        // Update fields based on selected type (not original type)
        if selectedType == "gp" {
            updatedAddress.gpName = gpName.isEmpty ? "" : gpName
            updatedAddress.gpPractice = gpPractice.isEmpty ? "" : gpPractice
            updatedAddress.gpAddress = gpAddress.isEmpty ? "" : gpAddress
            updatedAddress.gpPostcode = gpPostcode.isEmpty ? "" : gpPostcode
        } else {
            // Join split name fields back into fullName for the override
            let composedName = [title, firstName, surname]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            updatedAddress.fullName = composedName.isEmpty ? "" : composedName
            updatedAddress.dateOfBirth = dateOfBirth.isEmpty ? "" : dateOfBirth
            updatedAddress.mrn = mrn.isEmpty ? nil : mrn
            updatedAddress.addressLine1 = addressLine1.isEmpty ? "" : addressLine1
            updatedAddress.addressLine2 = addressLine2.isEmpty ? "" : addressLine2
            updatedAddress.city = city.isEmpty ? "" : city
            updatedAddress.county = county.isEmpty ? "" : county
            updatedAddress.postcode = postcode.isEmpty ? "" : postcode
            updatedAddress.phoneHome = phoneHome.isEmpty ? "" : phoneHome
            updatedAddress.phoneWork = phoneWork.isEmpty ? "" : phoneWork
            updatedAddress.phoneMobile = phoneMobile.isEmpty ? "" : phoneMobile
        }

        // Include type and prime changes from editing
        updatedAddress.addressType = selectedType
        updatedAddress.isPrime = isPrime

        do {
            try await repository.saveOverride(
                documentId: documentId,
                pageNumber: address.pageNumber ?? 1,
                matchAddressType: address.matchAddressType ?? address.addressType ?? "patient",
                updatedAddress: updatedAddress,
                reason: "corrected"
            )
            isEditingPatient = false
            onSave() // Trigger refresh
        } catch {
            print("Failed to save changes: \(error)")
        }

        isSavingPatient = false
    }

    private func dismissAddress() async {
        do {
            try await repository.dismissAddress(
                documentId: documentId,
                pageNumber: address.pageNumber ?? 1,
                addressType: address.matchAddressType ?? address.addressType ?? "patient"
            )
            isEditingPatient = false
            onSave()
        } catch {
            print("Failed to dismiss address: \(error)")
        }
    }

    private func deleteManualAddress() async {
        do {
            try await repository.deleteManualAddress(
                documentId: documentId,
                addressType: address.addressType ?? "patient"
            )
            onSave() // Trigger refresh
        } catch {
            print("Failed to delete address: \(error)")
        }
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

    @ViewBuilder
    private var nhsCandidatesView: some View {
        if let candidates = address.nhsGPCandidates, !candidates.isEmpty {
            Divider()
            Text("NHS Matches")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(candidates, id: \.odsCode) { candidate in
                NHSCandidateRow(candidate: candidate)
            }
        }
    }

    // Formatted addresses for sharing
    // Unified formatted address for sharing
    private var formattedAddress: String {
        var components: [String] = []

        if address.typedAddressType == .gp {
            // GP format
            if !gpName.isEmpty {
                components.append(gpName)
            }
            if !gpPractice.isEmpty {
                components.append(gpPractice)
            }
            if !gpAddress.isEmpty {
                components.append(gpAddress)
            }
            if !gpPostcode.isEmpty {
                components.append(gpPostcode)
            }
        } else {
            // Patient/Optician/Specialist format
            if !fullName.isEmpty {
                components.append(fullName)
            }
            if !addressLine1.isEmpty {
                components.append(addressLine1)
            }
            if !addressLine2.isEmpty {
                components.append(addressLine2)
            }
            if !city.isEmpty {
                components.append(city)
            }
            if !county.isEmpty {
                components.append(county)
            }
            if !postcode.isEmpty {
                components.append(postcode)
            }
        }

        return components.joined(separator: "\n")
    }

    // Unified copy function for macOS
    private func copyAddress() {
        #if os(macOS)
        let addressText = formattedAddress

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(addressText, forType: .string)

        // Show feedback
        patientCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            patientCopied = false
        }
        #endif
    }


    // MARK: - Prime Address System Helpers

    private var currentTypeDefinition: AddressTypeDefinition? {
        configManager.currentConfiguration.type(named: selectedType)
    }

    private var addressTypeLabel: String {
        if let typeDef = currentTypeDefinition {
            if typeDef.requiresSubtype && !subtypeName.isEmpty {
                return subtypeName
            }
            return "\(typeDef.name) Information"
        }
        return "Address Information"
    }

    private func togglePrimeStatus(_ newValue: Bool) async {
        do {
            try await repository.togglePrime(
                documentId: documentId,
                pageNumber: address.pageNumber ?? 1,
                addressType: selectedType,
                makePrime: newValue
            )
            onSave() // Trigger refresh
        } catch {
            print("Failed to toggle prime status: \(error)")
            // Revert the toggle on error
            isPrime = !newValue
        }
    }

    private func updateAddressType() async {
        do {
            let subtypeValue = currentTypeDefinition?.requiresSubtype == true ? subtypeName : nil
            try await repository.updateAddressType(
                documentId: documentId,
                pageNumber: address.pageNumber ?? 1,
                currentAddressType: address.addressType ?? "patient",
                newType: selectedType,
                specialistName: subtypeValue
            )
            onSave() // Trigger refresh
        } catch {
            print("Failed to update address type: \(error)")
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
    let onSubmit: () -> Void
    var isPostcode: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(label, text: isPostcode ? postcodeBinding : $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onSubmit)
                    #if os(iOS)
                    .autocapitalization(isPostcode ? .allCharacters : .none)
                    .disableAutocorrection(isPostcode)
                    #endif
            }
        }
    }

    private var postcodeBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                // Convert to uppercase for postcodes
                text = newValue.uppercased()
            }
        )
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

// MARK: - NHS Candidate Row
private struct NHSCandidateRow: View {
    let candidate: NHSCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(candidate.name ?? "Unknown")
                .font(.caption)
                .fontWeight(.medium)
            if let addr = candidate.addressLine1 {
                Text("\(addr), \(candidate.town ?? "")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(candidate.odsCode ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview
#Preview {
    AddressesView(documentId: "test_document")
}
