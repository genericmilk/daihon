import SwiftUI

struct AppsView: View {
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppsSidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            AppsDetailView()
        }
        .navigationSplitViewStyle(.balanced)
    }
}