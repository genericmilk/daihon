import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var state = AppState.shared
    @State private var startAtLogin: Bool = false
    @State private var showNotifications: Bool = true
    @State private var selectedManager: PackageManager = .npm
    @State private var alert: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences").font(.title2).bold()

            // General
            GroupBox(label: Text("General")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(get: { startAtLogin }, set: { newValue in
                        do {
                            try LoginItemManager.shared.setEnabled(newValue)
                            startAtLogin = newValue
                        } catch {
                            alert = "Failed to update login item: \(error.localizedDescription)"
                        }
                    })) {
                        Text("Start Daihon at login")
                    }
                    .toggleStyle(.switch)

                    Toggle("Show notifications", isOn: $showNotifications)
                        .toggleStyle(.switch)
                }
                .padding(.vertical, 6)
            }

            // Package Manager
            GroupBox(label: Text("Package Manager")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Preferred tool", selection: $selectedManager) {
                        ForEach(PackageManager.allCases) { pm in
                            Text(pm.displayName).tag(pm)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(helpTextForPackageManager(selectedManager))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }

            // About
            GroupBox(label: Text("About Daihon")) {
                HStack(alignment: .center, spacing: 12) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                    } else {
                        Image(systemName: "app")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daihon").font(.headline)
                        Text("© genericmilk 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            HStack {
                Spacer()
                Button("Cancel") { close(false) }
                Button("Save") { close(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .onAppear {
            startAtLogin = LoginItemManager.shared.isEnabled
            showNotifications = state.preferences.showNotifications
            selectedManager = state.preferences.packageManager
        }
        .alert(item: Binding(get: { alert.map { PrefAlertItem(msg: $0) } }, set: { _ in alert = nil }))
        { a in
            Alert(title: Text("Error"), message: Text(a.msg))
        }
    }

    func close(_ save: Bool) {
        if save {
            state.preferences.showNotifications = showNotifications
            state.preferences.packageManager = selectedManager
            state.savePreferences()
        }
        PreferencesWindowController.shared.close()
    }

    private func helpTextForPackageManager(_ pm: PackageManager) -> String {
        switch pm {
        case .npm: return "Uses `npm run <script>`"
        case .npx: return "Uses `npx <script>` for binaries in node_modules/.bin"
        case .yarn: return "Uses `yarn run <script>`"
        case .pnpm: return "Uses `pnpm run <script>`"
        case .bun: return "Uses `bun run <script>`"
        }
    }
}

struct PrefAlertItem: Identifiable {
    let id = UUID()
    let msg: String
}
