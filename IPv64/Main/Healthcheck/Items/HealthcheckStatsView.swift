//
//  HealthcheckStatsView.swift
//  IPv64
//
//  Created by Sebastian Rank on 16.01.23.
//

import SwiftUI

struct HealthcheckStatsView: View {
    
    @Binding var activeCount: Int
    @Binding var warningCount: Int
    @Binding var alarmCount: Int
    @Binding var pausedCount: Int
    
    @State var columnsGrid: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    
    var body: some View {
        VStack {
            LazyVGrid(columns: columnsGrid, spacing: 10) {
                HealthcheckStatsItem(statusType: StatusTypes.active, count: $activeCount)
                HealthcheckStatsItem(statusType: StatusTypes.warning, count: $warningCount)
                HealthcheckStatsItem(statusType: StatusTypes.alarm, count: $alarmCount)
                HealthcheckStatsItem(statusType: StatusTypes.pause, count: $pausedCount)
            }
            .padding()
        }
    }
}

struct HealthcheckStatsView_Previews: PreviewProvider {
    static var previews: some View {
        HealthcheckStatsView(activeCount: .constant(2), warningCount: .constant(0), alarmCount: .constant(3), pausedCount: .constant(1))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        HealthcheckStatsView(activeCount: .constant(2), warningCount: .constant(0), alarmCount: .constant(3), pausedCount: .constant(1))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}
