//
//  UserStorage.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import Combine
import SwiftUI

extension UserStorageWidget: @unchecked Sendable {}

public class UserStorageWidget: ObservableObject {
    class Storage {
        
        @AppStorage("API_KEY_WIDGET", store: UserStorageWidget.sharedDefault) var ApiKey: String = ""
        
        init() { }
    }
    
    
    public static let shared = UserStorageWidget()
    nonisolated(unsafe) public static let sharedDefault = UserDefaults(suiteName: "group.ipv64.net")
    private let storage = Storage()
    
    @Published public var ApiKey: String = "" {
        didSet {
            storage.ApiKey = ApiKey
        }
    }
    
    private init() {
        guard let sharedDefaults = UserStorageWidget.sharedDefault else {
            print("Failed to access shared UserDefaults.")
            return
        }
        
        #if DEBUG
        let userDefaultsDict = sharedDefaults.dictionaryRepresentation()
        for (key, value) in userDefaultsDict {
            print("\(key): \(value)")
        }
        #endif
        
        ApiKey = storage.ApiKey
    }
    
    public func clear() {
        ApiKey = ""
    }
}
