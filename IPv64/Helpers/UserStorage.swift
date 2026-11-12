//
//  UserStorage.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import Combine
import SwiftUI
import WidgetKit



@MainActor
public class UserStorage: ObservableObject {
    class Storage {
        
        @AppStorage("CURRENT_TAB", store: UserStorage.sharedDefault) var SelectedTab: Tabs = .domain
        @AppStorage("SHOW_WELCOME_VIEW", store: UserStorage.sharedDefault) var ShowWelcomeView: Bool = true
        @AppStorage("SHOW_LOGIN_VIEW", store: UserStorage.sharedDefault) var ShowLoginView: Bool = false
        @AppStorage("ENABLLE_LOCKSCREEN", store: UserStorage.sharedDefault) var EnableLogscreen: Bool = false
        @AppStorage("IS_INIT_DOMAIN", store: UserStorage.sharedDefault) var IsInitDomain: Bool = false
        @AppStorage("IN_APP_SWITCHER", store: UserStorage.sharedDefault) var InAppSwitcher: Bool = false
        @AppStorage("LAST_BUILD_NUMBER", store: UserStorage.sharedDefault) var LAST_BUILD_NUMBER: String = ""
        
        init() { }
    }
    
    
    public static let shared = UserStorage()
    nonisolated(unsafe) public static let sharedDefault = UserDefaults(suiteName: "group.ipv64.net")
    private let storage = Storage()
    @Published var storageError: String?
    @Published private(set) var sessionID = UUID()
    private var cachedUsers: [User]?
    private var isRestoringAfterStorageFailure = false
    private var isInitializing = true

    var users: [User] {
        if let cachedUsers { return cachedUsers }
        var users = (try? JSONDecoder().decode([User].self, from: UserAccounts)) ?? []
        var needsMigration = false
        for index in users.indices where users[index].uuid == nil {
            users[index].uuid = UUID().uuidString
            needsMigration = true
        }
        if needsMigration, let data = try? JSONEncoder().encode(users) { UserAccounts = data }
        cachedUsers = users
        return users
    }
    
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
            guard ApiKey != oldValue else { return }
            guard !isRestoringAfterStorageFailure else { return }
            do {
                if ApiKey.isEmpty {
                    try SecureStore.remove("API_KEY")
                } else {
                    try SecureStore.write(ApiKey.data(using: .utf8)!, account: "API_KEY")
                }
                UserStorage.sharedDefault?.removeObject(forKey: "API_KEY")
                sessionID = UUID()
            } catch {
                isRestoringAfterStorageFailure = true
                ApiKey = oldValue
                isRestoringAfterStorageFailure = false
                storageError = error.localizedDescription
            }
        }
    }
    
    @Published public var ApiKeyWidget: String = "" {
        didSet {
            guard ApiKeyWidget != oldValue else { return }
            guard !isRestoringAfterStorageFailure else { return }
            do {
                if ApiKeyWidget.isEmpty {
                    try SecureStore.remove("API_KEY_WIDGET")
                } else {
                    try SecureStore.write(ApiKeyWidget.data(using: .utf8)!, account: "API_KEY_WIDGET")
                }
                UserStorage.sharedDefault?.removeObject(forKey: "API_KEY_WIDGET")
                if !isInitializing {
                    WidgetHealthCacheStore.invalidate()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } catch {
                isRestoringAfterStorageFailure = true
                ApiKeyWidget = oldValue
                isRestoringAfterStorageFailure = false
                storageError = error.localizedDescription
            }
        }
    }
    
    @Published public var UserAccounts: Data = "".data(using: .utf8)! {
        didSet {
            guard UserAccounts != oldValue else { return }
            guard !isRestoringAfterStorageFailure else { return }
            do {
                try SecureStore.write(UserAccounts, account: "USER_ACCOUNTS")
                UserStorage.sharedDefault?.removeObject(forKey: "USER_ACCOUNTS")
                cachedUsers = nil
            } catch {
                isRestoringAfterStorageFailure = true
                UserAccounts = oldValue
                isRestoringAfterStorageFailure = false
                storageError = error.localizedDescription
            }
        }
    }
    
    @Published public var LAST_BUILD_NUMBER: String = "" {
        didSet {
            storage.LAST_BUILD_NUMBER = LAST_BUILD_NUMBER
        }
    }
    
    private init() {
        // Remove legacy values only after each secure write has succeeded.
        do {
            for key in ["API_KEY", "API_KEY_WIDGET", "USER_ACCOUNTS"] {
                let legacy: Data?
                if key == "USER_ACCOUNTS" {
                    legacy = Self.sharedDefault?.data(forKey: key)
                } else {
                    legacy = Self.sharedDefault?.string(forKey: key)?.data(using: .utf8)
                }
                if let legacy {
                    if try SecureStore.read(key) == nil {
                        try SecureStore.write(legacy, account: key)
                    }
                    Self.sharedDefault?.removeObject(forKey: key)
                }
            }
            ApiKey = try SecureStore.readString("API_KEY")
            ApiKeyWidget = try SecureStore.readString("API_KEY_WIDGET")
            UserAccounts = try SecureStore.read("USER_ACCOUNTS") ?? Data()
        } catch {
            storageError = error.localizedDescription
        }

        SelectedTab = storage.SelectedTab
        ShowWelcomeView = storage.ShowWelcomeView
        ShowLoginView = storage.ShowLoginView
        EnableLogscreen = storage.EnableLogscreen
        IsInitDomain = storage.IsInitDomain
        InAppSwitcher = storage.InAppSwitcher
        LAST_BUILD_NUMBER = storage.LAST_BUILD_NUMBER
        isInitializing = false
    }
    
    public func clear() {
        users.compactMap(\.uuid).forEach(LocalNodeStore.removeOwner)
        SelectedTab = .domain
        ShowWelcomeView = true
        ShowLoginView = false
        EnableLogscreen = false
        InAppSwitcher = false
        IsInitDomain = true
        ApiKey = ""
        ApiKeyWidget = ""
        UserAccounts = "".data(using: .utf8)!
        LAST_BUILD_NUMBER = ""
    }
}
