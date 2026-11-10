import SwiftUI

/// Navigation container of one tab: NavigationSplitView (list → detail) or NavigationStack (DNS64).
/// See the pattern comment in Router.swift.
struct TabContainer<Root: View>: View {
    @Bindable var router: Router
    let placeholderTitle: LocalizedStringKey
    let placeholderImage: String
    @ViewBuilder let root: () -> Root

    @Environment(ConnectedNodes.self) private var nodes

    var body: some View {
        Group {
            if router.usesSplitView {
                NavigationSplitView {
                    root().appScreenBackground()
                } detail: {
                    NavigationStack(path: $router.path) {
                        Group {
                            if let selection = router.selection {
                                RouteDestination(route: selection).id(selection)
                            } else {
                                ContentUnavailableView(placeholderTitle, systemImage: placeholderImage)
                            }
                        }
                        .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
                    }
                }
            } else {
                NavigationStack(path: $router.path) {
                    root().appReadableWidth().appScreenBackground().navigationDestination(for: Route.self) { RouteDestination(route: $0) }
                }
            }
        }
        .environment(router)
        .sheet(item: $router.sheet) { SheetDestination(sheet: $0).environment(router) }
        // Spec 01 §2.4: every navigation re-reads the connected nodes (prefs only).
        .onChange(of: router.path) { nodes.refresh() }
        .onChange(of: router.selection) { nodes.refresh() }
    }
}
