import SwiftUI

/// Kept so `Tabs.notification` (More hub) still compiles; the screen is now `ChannelsView`.
struct NotificationView: View {
    @Binding var popToRootTab: Tabs

    var body: some View { ChannelsView() }
}
