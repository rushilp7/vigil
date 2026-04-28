import SwiftUI

struct SettingsView: View {
    @AppStorage("emergencyContactPhone") private var emergencyContactPhone = ""
    @AppStorage("autoSendSafetyText") private var autoSendSafetyText = false
    @Environment(\.dismiss) private var dismiss

    private var phoneIsEmpty: Bool {
        emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. +12125550100", text: $emergencyContactPhone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Emergency Contact")
                } footer: {
                    Text("If your walk takes more than twice the expected time, Vigil will offer to text this number.")
                }

                Section {
                    Toggle("Auto-send safety text", isOn: $autoSendSafetyText)
                        .disabled(phoneIsEmpty)
                } footer: {
                    Text(phoneIsEmpty
                        ? "Save an emergency contact above to enable auto-send."
                        : "When on, Vigil texts your contact automatically if your walk runs long — no confirmation prompt.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
