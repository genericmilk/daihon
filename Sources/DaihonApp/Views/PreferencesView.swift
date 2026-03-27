import AppKit
import SwiftUI

enum PrefTab: String, CaseIterable, Identifiable {
    case general, packages
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .packages: return "Packages"
        }
    }
    
    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .packages: return "shippingbox"
        }
    }
}

struct PreferencesView: View {
    @State private var selectedTab: PrefTab = .general
    @StateObject private var state = AppState.shared
    @State private var startAtLogin: Bool = false
    @State private var showNotifications: Bool = true
    @State private var selectedManager: PackageManager = .npm
    @State private var npmPath: String = ""
    @State private var yarnPath: String = ""
    @State private var pnpmPath: String = ""
    @State private var bunPath: String = ""
    @State private var alert: String? = nil
    
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Daihon"
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case (let v?, let b?) where !b.isEmpty: return "Version \(v) (\(b))"
        case (let v?, _): return "Version \(v)"
        default: return "Version —"
        }
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 300, idealWidth: 320, maxWidth: 400)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            loadPreferences()
        }
        .alert("Error", isPresented: .constant(alert != nil)) {
            Button("OK") { alert = nil }
        } message: {
            Text(alert ?? "")
        }
    }
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // App header
            VStack(spacing: 12) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(12)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                }
                
                VStack(spacing: 4) {
                    Text(appName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(versionString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Navigation items
            VStack(spacing: 2) {
                ForEach(PrefTab.allCases) { tab in
                    sidebarItem(tab: tab)
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .navigationTitle("Preferences")
    }
    
    private func sidebarItem(tab: PrefTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                    .frame(width: 20)
                
                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private var detailView: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch selectedTab {
                case .general:
                    generalContent
                case .packages:
                    packagesContent
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle(selectedTab.title)
    }
    
    @ViewBuilder
    private var generalContent: some View {
        VStack(spacing: 20) {
            // Startup section
            VStack(alignment: .leading, spacing: 16) {
                Text("Startup")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Toggle(isOn: Binding(
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
                                    alert = "Failed to update login item: \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start at login")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Automatically launch Daihon when you log in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
            
            // Notifications section
            VStack(alignment: .leading, spacing: 16) {
                Text("Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Toggle("Show notifications", isOn: $showNotifications)
                    .toggleStyle(.switch)
                    .onChange(of: showNotifications) { value in
                        state.preferences.showNotifications = value
                        state.savePreferences()
                    }
                
                Text("Control when Daihon shows notifications for package operations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
            
            // About section
            VStack(alignment: .leading, spacing: 16) {
                Text("About")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Application")
                        Spacer()
                        Text(appName)
                            .foregroundColor(.secondary)
                    }
                    
                    #if DEBUG
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("DEBUG")
                            .foregroundColor(.orange)
                    }
                    #endif
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
    }
    
    @ViewBuilder
    private var packagesContent: some View {
        VStack(spacing: 20) {
            // Global default package manager
            VStack(alignment: .leading, spacing: 16) {
                Text("Global Default Package Manager")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Picker("Default tool", selection: $selectedManager) {
                    ForEach(PackageManager.allCases) { pm in
                        Text(pm.displayName).tag(pm)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedManager) { value in
                    state.preferences.packageManager = value
                    state.savePreferences()
                }
                
                Text(helpTextForPackageManager(selectedManager))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("This is the default package manager used for all apps. You can override this for individual apps in the Apps panel.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
            
            // Per-app overrides
            VStack(alignment: .leading, spacing: 16) {
                Text("Per-App Overrides")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if state.projects.isEmpty {
                    Text("No apps configured yet. Add apps in the Apps panel to set individual package managers.")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(state.projects) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(project.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(project.packageManager?.displayName ?? "Global Default (\(selectedManager.displayName))")
                                    .font(.caption)
                                    .foregroundColor(project.packageManager == nil ? .secondary : .primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Text("Configure individual app package managers in the Apps panel.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
            
            // Custom binary paths
            VStack(alignment: .leading, spacing: 16) {
                Text("Custom Binary Paths")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("If package managers are not found in your PATH, specify their full paths here. Leave empty to use system PATH.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    binaryPathField(title: "npm", binding: $npmPath, placeholder: "/usr/local/bin/npm")
                    binaryPathField(title: "yarn", binding: $yarnPath, placeholder: "/usr/local/bin/yarn")
                    binaryPathField(title: "pnpm", binding: $pnpmPath, placeholder: "/usr/local/bin/pnpm")
                    binaryPathField(title: "bun", binding: $bunPath, placeholder: "/usr/local/bin/bun")
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
            .onChange(of: npmPath) { state.preferences.npmBinaryPath = $0; state.savePreferences() }
            .onChange(of: yarnPath) { state.preferences.yarnBinaryPath = $0; state.savePreferences() }
            .onChange(of: pnpmPath) { state.preferences.pnpmBinaryPath = $0; state.savePreferences() }
            .onChange(of: bunPath) { state.preferences.bunBinaryPath = $0; state.savePreferences() }
        }
    }
    
    private func binaryPathField(title: String, binding: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
        }
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
    
    private func loadPreferences() {
        startAtLogin = LoginItemManager.shared.isEnabled
        showNotifications = state.preferences.showNotifications
        selectedManager = state.preferences.packageManager
        npmPath = state.preferences.npmBinaryPath
        yarnPath = state.preferences.yarnBinaryPath
        pnpmPath = state.preferences.pnpmBinaryPath
        bunPath = state.preferences.bunBinaryPath
    }
}