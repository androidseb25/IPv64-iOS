//
//  LogItemView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//

import Foundation
import SwiftUI
import IPv64

struct LogItemView: View {
    let log: LogEntry
    
    var body: some View {
        VStack {
            Text(log.title ?? "")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(log.message ?? "")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 5)
            Text(log.time?.formatted(date: .numeric, time: .standard) ?? "")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
