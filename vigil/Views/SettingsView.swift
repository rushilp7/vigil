import SwiftUI

struct SettingsView: View {
    @AppStorage("emergencyContactPhone") private var emergencyContactPhone = ""
    @Environment(\.dismiss) private var dismiss

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
