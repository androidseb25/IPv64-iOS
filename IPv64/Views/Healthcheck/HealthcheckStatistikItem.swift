//
//  HealthcheckStatistikItem.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 27.10.25.
//
import Foundation
import SwiftUI

struct HealthcheckStatistikItem: View {
    
    @State var status: Status
    @Binding var count: Int
    
    var body: some View {
        VStack {
            if #available(iOS 26.0, *) {
                content
                    .background(status.color)
                    .clipShape(.rect(corners: .concentric, isUniform: true))
            } else {
                content
                    .background(RoundedRectangle(cornerRadius: 16).fill(status.color))
            }
        }
    }
    
    private var content: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(status.label)
                        .bold()
                        .lineLimit(1)
                        .font(.system(.title2, design: .rounded))
                    Text("\(count)")
                        .font(.system(.title, design: .rounded))
                }
                Spacer()
                Image(systemName: status.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .offset(y: status.id == 4 ? -5 : 0)
            }
            .foregroundColor(.white)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let columnsGrid: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    List {
        LazyVGrid(columns: columnsGrid, spacing: 10) {
            HealthcheckStatistikItem(status: Status.active, count: .constant(5))
            HealthcheckStatistikItem(status: Status.warning, count: .constant(5))
            HealthcheckStatistikItem(status: Status.alarm, count: .constant(5))
            HealthcheckStatistikItem(status: Status.pause, count: .constant(5))
        }
        .padding()
        .listStyle(.plain)
        .listRowInsets(EdgeInsets(top: -16, leading: -16, bottom: -16, trailing: -16))
        .listRowBackground(Color.clear)
    }
}
