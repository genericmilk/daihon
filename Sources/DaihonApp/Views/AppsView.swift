import SwiftUI

struct AppsView: View {
    var body: some View {
        HSplitView {
            AppsSidebarView()
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
            
            AppsDetailView()
                .frame(minWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}