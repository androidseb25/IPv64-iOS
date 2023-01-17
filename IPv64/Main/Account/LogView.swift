//
//  LogView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct LogView: View {
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var myLogs: Logs = Logs(logs: [])
    
    var body: some View {
        ZStack {
            VStack {
                Form {
                    Section("Letzten 10 Logs") {
                        ForEach(myLogs.logs!.prefix(10), id: \.id) { log in
                            LogItemView(log: log)
                        }
                    }
                }
            }
            
            if api.isLoading {
                VStack() {
                    Spinner(isAnimating: true, style: .large, color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
        .onAppear {
            Task {
                myLogs = await api.GetLogs()!
            }
        }
        .navigationTitle("Logs")
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
