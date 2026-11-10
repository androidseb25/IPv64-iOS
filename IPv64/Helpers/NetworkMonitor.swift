//
//  NetworkMonitor.swift
//  IPv64
//
//  Created by Sebastian Rank on 03.11.25.
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    
    @Published private(set) var isConnected: Bool
    
    private let networkMonitor: NWPathMonitor
    private let workerQueue: DispatchQueue

    init() {
        self.networkMonitor = NWPathMonitor()
        self.workerQueue = DispatchQueue(label: "Monitor")
        self.isConnected = false

        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { @MainActor in
                let connected = path.status == .satisfied
                if self.isConnected != connected { self.isConnected = connected }
            }
        }
        networkMonitor.start(queue: workerQueue)
    }

    deinit { networkMonitor.cancel() }
}

