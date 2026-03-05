import SwiftUI

struct PatientSearchView: View {
    @State private var searchText = ""
    @State private var results: [ResolvedPatient] = []
    @State private var isLoading = true

    let addressService: AddressSearchService
    let onSelect: (ResolvedPatient) -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
        }
        .task {
            isLoading = true
            let service = addressService
            do {
                try await Task.detached {
                    try service.loadAll()
                }.value
            } catch {
                #if DEBUG
                print("[PatientSearch] Load failed: \(error)")
                #endif
            }
            isLoading = false
        }
        .navigationTitle("New Letter")
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search patients by name, DOB, or MRN...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit { performSearch() }
                .onChange(of: searchText) { _, _ in
                    performSearch()
                }
        }
        .padding()
    }

    private var resultsList: some View {
        Group {
            if isLoading {
                ProgressView("Loading patients...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Search for a patient to start a letter")
                        .foregroundStyle(.secondary)
                    Text("\(addressService.patientCount) patients available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                Text("No patients matching \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { patient in
                    PatientResultRow(patient: patient)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(patient) }
                }
            }
        }
    }

    private func performSearch() {
        results = addressService.search(query: searchText)
    }
}

private struct PatientResultRow: View {
    let patient: ResolvedPatient

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(patient.fullName)
                    .font(.headline)
                Spacer()
                if let mrn = patient.mrn {
                    Text(mrn)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            HStack(spacing: 16) {
                if let dob = patient.dateOfBirth, !dob.isEmpty {
                    Label(dob, systemImage: "calendar")
                }
                if let gp = patient.gpName, !gp.isEmpty {
                    Label(gp, systemImage: "cross.fill")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
