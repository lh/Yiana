//
//  AddressesView.swift
//  Yiana
//
//  Displays extracted addresses for a document (read-only)
//

import SwiftUI

struct AddressesView: View {
    let documentId: String
    @StateObject private var repository = AddressRepository()
    @State private var addresses: [ExtractedAddress] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                            AddressCard(address: address)
                        }
                    }
                }
            }
        }
        .task {
            await loadAddresses()
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
                    if let name = address.fullName {
                        AddressInfoRow(label: "Name", value: name, icon: "person")
                    }
                    if let dob = address.dateOfBirth {
                        AddressInfoRow(label: "Date of Birth", value: dob, icon: "calendar")
                    }
                    if let formattedAddress = address.formattedPatientAddress {
                        AddressInfoRow(label: "Address", value: formattedAddress, icon: "house")
                    }
                    if let postcode = address.postcode {
                        PostcodeRow(postcode: postcode, isValid: address.postcodeValid)
                    }
                    if let phones = address.formattedPhones {
                        AddressInfoRow(label: "Phone", value: phones, icon: "phone")
                    }
                }
            }

            // GP Information
            if address.hasGPInfo {
                VStack(alignment: .leading, spacing: 8) {
                    if let gpName = address.gpName {
                        AddressInfoRow(label: "GP Name", value: gpName, icon: "stethoscope")
                    }
                    if let practice = address.gpPractice {
                        AddressInfoRow(label: "Practice", value: practice, icon: "building.2")
                    }
                    if let gpAddress = address.gpAddress {
                        AddressInfoRow(label: "Address", value: gpAddress, icon: "house")
                    }
                    if let gpPostcode = address.gpPostcode {
                        AddressInfoRow(label: "Postcode", value: gpPostcode, icon: "mappin.circle")
                    }
                    if let odsCode = address.gpOdsCode {
                        AddressInfoRow(label: "ODS Code", value: odsCode, icon: "number")
                    }
                }
            }

            // Metadata
            if let confidence = address.extractionConfidence {
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
