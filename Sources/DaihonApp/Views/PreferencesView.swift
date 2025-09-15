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
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case let (v?, b?) where !b.isEmpty: return "Version \(v) (\(b))"
        case let (v?, _): return "Version \(v)"
        default: return "Version —"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
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
        .alert(item: Binding(get: { alert.map { PrefAlertItem(msg: $0) } }, set: { _ in alert = nil }))
        { a in
            Alert(title: Text("Error"), message: Text(a.msg))
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header styled like musumo
            VStack(spacing: 8) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 70, height: 70)
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
            List(PrefTab.allCases, selection: $tab) { item in
                Label(item.title, systemImage: iconName(for: item))
                    .tag(item)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)

            Spacer(minLength: 0)
        }
        .background(Color.clear)
        .modifier(GlassSidebarBackground())
        .frame(width: 240)
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
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var generalView: some View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var packagesView: some View {
        GroupBox(label: Text("Package Manager")) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Preferred tool", selection: $selectedManager) {
                    ForEach(PackageManager.allCases) { pm in
                        Text(pm.displayName).tag(pm)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(helpTextForPackageManager(selectedManager))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
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
        Group {
            #if swift(>=6.0)
            contentBackground(content)
            #else
            contentBackground(content)
            #endif
        }
    }

    @ViewBuilder
    private func contentBackground(_ content: Content) -> some View {
        if #available(macOS 15.0, *) {
            // Prefer Liquid Glass when available
            content
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // Use glass-style background when available (macOS 15+)
                .modifier(_GlassBackgroundCompat())
                .padding(8)
        } else {
            // Fallback to material on older macOS
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// A tiny shim to keep references to Liquid Glass APIs isolated.
@available(macOS 15.0, *)
private struct _GlassBackgroundCompat: ViewModifier {
    func body(content: Content) -> some View {
        // As Apple’s APIs evolve, prefer glassEffect or glassBackgroundEffect here.
        // Using background modifier to avoid compile-time issues on older SDKs.
        // Replace with `.glassEffect()` or `.glassBackgroundEffect(in:)` when supported by toolchain.
        content
            .background(.thinMaterial)
    }
}

// MARK: - Helpers
private func iconName(for tab: PrefTab) -> String {
    switch tab {
    case .general: return "gearshape"
    case .packages: return "shippingbox"
    }
}
