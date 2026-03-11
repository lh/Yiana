import SwiftUI

struct PatientSearchView: View {
    @State private var searchText = ""
    @State private var results: [ResolvedPatient] = []
    @State private var isLoading = true
    @State private var loadError: String?

    let addressService: AddressSearchService
    let workListItems: [WorkListItem]
    let onSelect: (ResolvedPatient) -> Void

    private var workListNameKeys: [Set<String>] {
        workListItems.map(\.nameKey)
    }

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
                loadError = error.localizedDescription
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
                if !workListItems.isEmpty {
                    workListSuggestions
                } else {
                    emptySearchPlaceholder
                }
            } else if results.isEmpty && addressService.patientCount > 0 {
                Text("No patients matching \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                emptySearchPlaceholder
            } else {
                List(results) { patient in
                    PatientResultRow(patient: patient, isWorkList: isWorkListPatient(patient))
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(patient) }
                }
            }
        }
    }

    private var workListSuggestions: some View {
        let patients = addressService.workListPatients(items: workListItems)
        return Group {
            if patients.isEmpty {
                emptySearchPlaceholder
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Clinic List")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    List(patients) { patient in
                        PatientResultRow(patient: patient, isWorkList: true)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(patient) }
                    }
                }
            }
        }
    }

    private var emptySearchPlaceholder: some View {
        Group {
            if let loadError {
                noDataView(
                    icon: "exclamationmark.icloud",
                    iconColor: .orange,
                    title: "Unable to load patient data",
                    message: loadError
                )
            } else if addressService.patientCount == 0 {
                noDataView(
                    icon: "building.2",
                    iconColor: .secondary,
                    title: "No patient data available",
                    message: "Yiale requires patient data from Yiana to compose letters.\nImport and process documents in Yiana first, then patient records will appear here automatically via iCloud."
                )
            } else {
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
            }
        }
    }

    private func noDataView(icon: String, iconColor: Color, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func isWorkListPatient(_ patient: ResolvedPatient) -> Bool {
        let words = Set(patient.fullName.lowercased().split(separator: " ").map(String.init))
        return workListNameKeys.contains { $0.isSubset(of: words) }
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            results = []
            return
        }
        let all = addressService.search(query: searchText)
        let (workList, rest) = all.reduce(into: ([ResolvedPatient](), [ResolvedPatient]())) { acc, patient in
            if isWorkListPatient(patient) {
                acc.0.append(patient)
            } else {
                acc.1.append(patient)
            }
        }
        results = workList + rest
    }
}

private struct PatientResultRow: View {
    let patient: ResolvedPatient
    var isWorkList: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(patient.fullName)
                    .font(.headline)
                if isWorkList {
                    Image(systemName: "list.clipboard")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
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
