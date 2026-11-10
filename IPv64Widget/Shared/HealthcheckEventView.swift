import SwiftUI

struct HealthcheckEventView: View {
    var showSmall: Bool = true
    /// Newest first.
    let states: [String]

    var body: some View {
        GeometryReader { geometry in
            let barWidth: CGFloat = showSmall ? 5 : 7
            let barSpacing: CGFloat = 5
            let maxCount = Int(geometry.size.width / (barWidth + barSpacing))

            HStack(spacing: barSpacing) {
                ForEach(Array(states.prefix(maxCount).reversed().enumerated()), id: \.offset) { _, state in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(WidgetState.color(state))
                        .frame(width: barWidth, height: showSmall ? 20 : 34)
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .frame(height: showSmall ? 20 : 34)
    }
}

#Preview {
    HealthcheckEventView(states: ["up", "up", "down", "degraded", "up", "paused", "pending", "up", "up", "up"])
}
