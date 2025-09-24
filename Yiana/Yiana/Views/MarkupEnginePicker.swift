//
//  MarkupEnginePicker.swift
//  Yiana
//
//  Temporary UI to switch between markup implementations at runtime (iOS, DEBUG)
//

import SwiftUI

#if os(iOS)
struct MarkupEnginePicker: View {
    @AppStorage("yiana.markupEngine") private var engineRaw: String = "pencil"

    private var selectionBinding: Binding<String> {
        Binding<String>(
            get: { engineRaw.isEmpty ? "pencil" : engineRaw },
            set: { newValue in
                engineRaw = newValue
                switch newValue {
                case "ql": MarkupConfiguration.activeImplementation = .qlPreviewController
                case "pencil": MarkupConfiguration.activeImplementation = .pencilKit
                default: MarkupConfiguration.activeImplementation = .pencilKit
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Implementation", selection: selectionBinding) {
                Text("PencilKit").tag("pencil")
                if MarkupConfiguration.isQLPreviewControllerFixed {
                    Text("QuickLook").tag("ql")
                }
            }
            .pickerStyle(.segmented)

            Text(helpText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var helpText: String {
        switch engineRaw {
        case "pencil": return "PencilKit overlay with flatten-on-save."
        case "ql": return "QuickLook Markup (use only if Apple bug is fixed)."
        default: return "PencilKit overlay with flatten-on-save."
        }
    }
}

#Preview {
    MarkupEnginePicker()
}
#endif

