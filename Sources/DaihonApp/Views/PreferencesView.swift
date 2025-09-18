import AppKit
import SwiftUI

enum PrefTab: String, CaseIterable, Identifiable, Hashable {
    case general, packages
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .packages: return "Packages"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var state = AppState.shared
    @State private var startAtLogin: Bool = false
    @State private var showNotifications: Bool = true
    @State private var selectedManager: PackageManager = .npm
    @State private var alert: String? = nil
    @State private var tab: PrefTab = .general

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Daihon"
    }

    private var versionString: String {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case (let v?, let b?) where !b.isEmpty: return "Version \(v) (\(b))"
        case (let v?, _): return "Version \(v)"
        default: return "Version —"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            sidebar
            content
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .onAppear {
            startAtLogin = LoginItemManager.shared.isEnabled
            showNotifications = state.preferences.showNotifications
            selectedManager = state.preferences.packageManager
        }
        .onChange(of: showNotifications) { value in
            state.preferences.showNotifications = value
            state.savePreferences()
        }
        .onChange(of: selectedManager) { value in
            state.preferences.packageManager = value
            state.savePreferences()
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .ignoresSafeArea()
        }
        .alert(
            item: Binding(get: { alert.map { PrefAlertItem(msg: $0) } }, set: { _ in alert = nil })
        ) { a in
            Alert(title: Text("Error"), message: Text(a.msg))
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header styled like musumo
            VStack(spacing: 9) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 90, height: 90)
                        .cornerRadius(14)
                } else {
                    Image(systemName: "app")
                        .font(.title)
                        .foregroundColor(.accentColor)
                }

                Text(appName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(versionString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                #if DEBUG
                    Text("DEBUG BUILD")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                        .padding(.top, 2)
                #endif

                // Copyright moved under version/debug text
                Text("© genericmilk 2025")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .padding(.vertical, 20)

            // Navigation items styled like musumo
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(PrefTab.allCases) { item in
                        sidebarRow(for: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(minWidth: 200)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 240, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassPanel(radius: 16)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                switch tab {
                case .general: generalView
                case .packages: packagesView
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPanel(radius: 16)
    }

    private func sidebarRow(for item: PrefTab) -> some View {
        let isSelected = item == tab
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                tab = item
            }
        } label: {
            Label(item.title, systemImage: iconName(for: item))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(isSelected ? .accentColor : .primary)
                .background(
                    shape.fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                )
                .overlay(
                    shape.stroke(
                        isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                )
                .clipShape(shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private var generalView: some View {
        GroupBox(label: sectionHeader("General")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(
                    isOn: Binding(
                        get: { startAtLogin },
                        set: { newValue in
                            Task {
                                do {
                                    try await LoginItemManager.shared.setEnabled(newValue)
                                    await MainActor.run {
                                        startAtLogin = newValue
                                    }
                                } catch {
                                    await MainActor.run {
                                        alert =
                                            "Failed to update login item: \(error.localizedDescription)"
                                    }
                                }
                            }
                        })
                ) {
                    Text("Start Daihon at login")
                }
                .toggleStyle(.switch)

                Toggle("Show notifications", isOn: $showNotifications)
                    .toggleStyle(.switch)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var packagesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: sectionHeader("Global Default Package Manager")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Default tool", selection: $selectedManager) {
                        ForEach(PackageManager.allCases) { pm in
                            Text(pm.displayName).tag(pm)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(helpTextForPackageManager(selectedManager))
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text(
                        "This is the default package manager used for all apps. You can override this for individual apps in the Apps panel."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.leading, 4)
            }

            GroupBox(label: sectionHeader("Per-App Overrides")) {
                VStack(alignment: .leading, spacing: 8) {
                    if state.projects.isEmpty {
                        Text(
                            "No apps configured yet. Add apps in the Apps panel to set individual package managers."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    } else {
                        ForEach(state.projects) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                    Text(project.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(
                                    project.packageManager?.displayName
                                        ?? "Global Default (\(selectedManager.displayName))"
                                )
                                .font(.footnote)
                                .foregroundColor(
                                    project.packageManager == nil ? .secondary : .primary)
                            }
                            .padding(.vertical, 2)
                        }

                        Text("Configure individual app package managers in the Apps panel.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // About section removed per request

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

// MARK: - Components

private struct GlassSidebarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .platformGlassBackground(in: Rectangle())
    }
}

// Kept for compatibility; no-op wrapper now that we have platformGlassBackground.
@available(macOS 15.0, *)
private struct _GlassBackgroundCompat: ViewModifier {
    func body(content: Content) -> some View { content }
}

// MARK: - Helpers
private func iconName(for tab: PrefTab) -> String {
    switch tab {
    case .general: return "gearshape"
    case .packages: return "shippingbox"
    }
}

@ViewBuilder
private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 14, weight: .semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .padding(.bottom, 10)
}
