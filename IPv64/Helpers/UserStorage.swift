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
        @AppStorage("IS_INIT_DOMAIN", store: UserStorage.sharedDefault) var IsInitDomain: Bool = false
        @AppStorage("API_KEY", store: UserStorage.sharedDefault) var ApiKey: String = ""
        @AppStorage("API_KEY_WIDGET", store: UserStorage.sharedDefault) var ApiKeyWidget: String = ""
        @AppStorage("USER_ACCOUNTS", store: UserStorage.sharedDefault) var UserAccounts: Data = "".data(using: .utf8)!
        @AppStorage("IN_APP_SWITCHER", store: UserStorage.sharedDefault) var InAppSwitcher: Bool = false
        
        init() { }
    }
    
    
    public static let shared = UserStorage()
    nonisolated(unsafe) public static let sharedDefault = UserDefaults(suiteName: "group.ipv64.net")
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
    
    @Published public var IsInitDomain: Bool = true {
        didSet {
            storage.IsInitDomain = IsInitDomain
        }
    }
    
    @Published public var InAppSwitcher: Bool = false {
        didSet {
            storage.InAppSwitcher = InAppSwitcher
        }
    }
    
    @Published public var ApiKey: String = "" {
        didSet {
            storage.ApiKey = ApiKey
        }
    }
    
    @Published public var ApiKeyWidget: String = "" {
        didSet {
            storage.ApiKeyWidget = ApiKeyWidget
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
        IsInitDomain = storage.IsInitDomain
        ApiKey = storage.ApiKey
        ApiKeyWidget = storage.ApiKeyWidget
        UserAccounts = storage.UserAccounts
        InAppSwitcher = storage.InAppSwitcher
    }
    
    public func clear() {
        SelectedTab = .domain
        ShowWelcomeView = true
        ShowLoginView = false
        EnableLogscreen = false
        InAppSwitcher = false
        IsInitDomain = true
        ApiKey = ""
        ApiKeyWidget = ""
        UserAccounts = "".data(using: .utf8)!
    }
}
