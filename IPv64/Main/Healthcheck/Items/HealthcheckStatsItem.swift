//
//  HealthcheckStatsItem.swift
//  IPv64
//
//  Created by Sebastian Rank on 16.01.23.
//

import SwiftUI

struct HealthcheckStatsItem: View {
    
    @State var statusType: StatusTyp
    @Binding var count: Int
    
    var body: some View {
        VStack {
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(statusType.name!)
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("\(count)")
                            .font(.system(.title, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: statusType.icon!)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .offset(y: statusType.statusId == 4 ? -5 : 0)
                }
                .foregroundColor(.white)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(statusType.color!))
        }
    }
}

struct HealthcheckStatsItem_Previews: PreviewProvider {
    static var previews: some View {
        HealthcheckStatsItem(statusType: StatusTypes.pause, count: .constant(20))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        HealthcheckStatsItem(statusType: StatusTypes.pause, count: .constant(20))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}
