import SwiftUI
import Observation

// MARK: - Navigation pattern (read before adding a screen)
//
// One `Router` per tab (owned by MainTabView, available as `@Environment(Router.self)` in every screen).
//
// Split tabs (DynDNS, Healthchecks, CDN/Proxy, More) are a NavigationSplitView:
//   sidebar = the tab's root list, detail = NavigationStack(path: router.path) rooted at `router.selection`.
//   Root lists bind the selection and use value links (compact width collapses to one stack automatically):
//
//       @Environment(Router.self) private var router
//       var body: some View {
//           @Bindable var router = router
//           List(selection: $router.selection) {
//               ForEach(domains) { d in
//                   NavigationLink(value: Route.domainDetail(name: d.name)) { ListRow(verbatim: d.name) }
//               }
//           }
//       }
//
// Inside a detail screen push further screens with `NavigationLink(value: Route.x)` or `router.push(.x)`.
// `router.push` on a split tab with nothing selected sets the selection (e.g. a "+" toolbar button in the list).
// After a mutation call `router.pop()` (leaves the detail when its path is empty) and `router.reload()`;
// list screens reload with `.task(id: router.reloadToken)` (combine with `session.accountRevision` if the
// data depends on the account). `router.flash` hands a one-shot message back to the previous screen
// (Android `ACCOUNT_REMOVED_MESSAGE` / snackbars); the receiver shows it and sets it to `nil`.
// DNS64 is a plain NavigationStack: `push` appends, `pop` removes the last screen.
// Shared sheets: `router.sheet = .directAccess(nodeId:)`; screen-local sheets use their own `.sheet(item:)`.

/// Navigation state of one tab.
@Observable
final class Router {
    let usesSplitView: Bool

    /// Detail root of a split tab (the selected list row). Changing it resets `path`.
    var selection: Route? {
        didSet { if selection != oldValue { path = [] } }
    }

    /// Screens pushed on top of the detail root (split) or the tab root (stack).
    var path: [Route] = []

    var sheet: SheetRoute?

    /// Bumped by `reload()`; list screens observe it with `.task(id:)`.
    private(set) var reloadToken = 0

    /// One-shot message for the screen below (snackbar-like); consumer sets it back to `nil`.
    var flash: String?

    init(usesSplitView: Bool) {
        self.usesSplitView = usesSplitView
    }

    /// `true` while only the tab root is visible (Android "route is a bottom tab root").
    var isAtRoot: Bool { path.isEmpty && selection == nil }

    func push(_ route: Route) {
        if usesSplitView && selection == nil {
            selection = route
        } else {
            path.append(route)
        }
    }

    /// Replaces the detail column (split) or the whole stack with `route`.
    func show(_ route: Route) {
        if usesSplitView {
            selection = route
            path = []
        } else {
            path = [route]
        }
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        } else if usesSplitView {
            selection = nil
        }
    }

    func popToRoot() {
        path = []
        if usesSplitView { selection = nil }
    }

    func reload() { reloadToken += 1 }
}
