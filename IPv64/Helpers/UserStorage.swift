//
//  UserStorage.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import Combine
import SwiftUI

extension UserStorage: @unchecked Sendable {}

public class UserStorage: ObservableObject {
    class Storage {
        
        @AppStorage("CURRENT_TAB", store: UserStorage.sharedDefault) var SelectedTab: Tabs = .domain
        @AppStorage("SHOW_WELCOME_VIEW", store: UserStorage.sharedDefault) var ShowWelcomeView: Bool = true
        @AppStorage("SHOW_LOGIN_VIEW", store: UserStorage.sharedDefault) var ShowLoginView: Bool = false
        @AppStorage("ENABLLE_LOCKSCREEN", store: UserStorage.sharedDefault) var EnableLogscreen: Bool = false
        @AppStorage("API_KEY", store: UserStorage.sharedDefault) var ApiKey: String = ""
        @AppStorage("USER_ACCOUNTS", store: UserStorage.sharedDefault) var UserAccounts: Data = "".data(using: .utf8)!
        
        init() { }
    }
    
    
    public static let shared = UserStorage()
    nonisolated(unsafe) public static let sharedDefault = UserDefaults(suiteName: "de.rpicloud.IPv64")
    private let storage = Storage()
    
    @Published public var SelectedTab: Tabs = .domain {
        didSet {
            storage.SelectedTab = SelectedTab
        }
    }
    
    @Published public var ShowWelcomeView: Bool = true {
        didSet {
            storage.ShowWelcomeView = ShowWelcomeView
        }
    }
    
    @Published public var ShowLoginView: Bool = false {
        didSet {
            storage.ShowLoginView = ShowLoginView
        }
    }
    
    @Published public var EnableLogscreen: Bool = false {
        didSet {
            storage.EnableLogscreen = EnableLogscreen
        }
    }
    
    @Published public var ApiKey: String = "" {
        didSet {
            storage.ApiKey = ApiKey
        }
    }
    
    @Published public var UserAccounts: Data = "".data(using: .utf8)! {
        didSet {
            storage.UserAccounts = UserAccounts
        }
    }
    
    private init() {
        guard let sharedDefaults = UserStorage.sharedDefault else {
            print("Failed to access shared UserDefaults.")
            return
        }
        
        #if DEBUG
        let userDefaultsDict = sharedDefaults.dictionaryRepresentation()
        for (key, value) in userDefaultsDict {
            print("\(key): \(value)")
        }
        #endif
        
        SelectedTab = storage.SelectedTab
        ShowWelcomeView = storage.ShowWelcomeView
        ShowLoginView = storage.ShowLoginView
        EnableLogscreen = storage.EnableLogscreen
        ApiKey = storage.ApiKey
        UserAccounts = storage.UserAccounts
    }
    
    public func clear() {
        SelectedTab = .domain
        ShowWelcomeView = true
        ShowLoginView = false
        EnableLogscreen = false
        ApiKey = ""
        UserAccounts = "".data(using: .utf8)!
    }
}
