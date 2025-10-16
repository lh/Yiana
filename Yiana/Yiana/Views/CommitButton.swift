//
//  CommitButton.swift
//  Yiana
//
//  Commit button with confirmation and visual feedback
//  Following the "Digital Paper" paradigm - making ink permanent
//

#if os(macOS)
import SwiftUI

struct CommitButton: View {
    let hasAnnotations: Bool
    let onCommit: () -> Void

    @State private var showingConfirmation = false
    @State private var isCommitting = false
    @State private var showInkDryingAnimation = false

    var body: some View {
        Button(action: {
            if hasAnnotations {
                showingConfirmation = true
            }
        }) {
            HStack(spacing: 6) {
                if isCommitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: showInkDryingAnimation ? "checkmark.circle.fill" : "checkmark.circle")
                        .imageScale(.large)
                        .symbolRenderingMode(.hierarchical)
                }

                Text(buttonText)
                    .fontWeight(.medium)
            }
            .foregroundColor(buttonColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(buttonBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(buttonBorderColor, lineWidth: 1)
            )
        }
        .disabled(!hasAnnotations || isCommitting)
        .help(helpText)
        .keyboardShortcut(.return, modifiers: .command)
        .confirmationDialog(
            "Make Annotations Permanent?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Commit to Paper", role: .destructive) {
                performCommit()
            }
            Button("Continue Editing", role: .cancel) {}
        } message: {
            Text("This will permanently add all annotations to the PDF, like ink drying on paper. This action cannot be undone.")
        }
        .animation(.easeInOut(duration: 0.3), value: showInkDryingAnimation)
    }

    // MARK: - Computed Properties

    private var buttonText: String {
        if isCommitting {
            return "Committing..."
        } else if showInkDryingAnimation {
            return "Committed"
        } else if hasAnnotations {
            return "Commit to Paper"
        } else {
            return "No Annotations"
        }
    }

    private var buttonColor: Color {
        if !hasAnnotations {
            return .secondary
        } else if showInkDryingAnimation {
            return .green
        } else {
            return .white
        }
    }

    private var buttonBackgroundColor: Color {
        if !hasAnnotations {
            return Color(NSColor.controlBackgroundColor)
        } else if showInkDryingAnimation {
            return Color.green.opacity(0.15)
        } else {
            return Color.accentColor
        }
    }

    private var buttonBorderColor: Color {
        if !hasAnnotations {
            return Color(NSColor.separatorColor)
        } else if showInkDryingAnimation {
            return Color.green
        } else {
            return Color.accentColor.opacity(0.8)
        }
    }

    private var helpText: String {
        if !hasAnnotations {
            return "Add annotations before committing"
        } else {
            return "Permanently apply annotations (⌘Return)"
        }
    }

    // MARK: - Methods

    private func performCommit() {
        isCommitting = true

        // Simulate ink drying with a slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onCommit()
            isCommitting = false
            showInkDryingAnimation = true

            // Reset animation after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showInkDryingAnimation = false
            }
        }
    }
}

// MARK: - Ink Drying Animation View

struct InkDryingAnimation: View {
    @State private var opacity: Double = 1.0

    var body: some View {
        Text("✓ Ink Applied")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2.0)) {
                    opacity = 0.0
                }
            }
    }
}

// MARK: - Preview

struct CommitButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // With annotations
            CommitButton(hasAnnotations: true, onCommit: {
                print("Committed!")
            })

            // Without annotations
            CommitButton(hasAnnotations: false, onCommit: {
                print("Nothing to commit")
            })

            // Animation preview
            InkDryingAnimation()
        }
        .padding()
        .frame(width: 400)
    }
}

#endif
