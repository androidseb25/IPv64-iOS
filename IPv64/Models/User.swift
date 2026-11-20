//
//  User.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 22.10.25.
//

import Foundation

struct User: Codable {
    var uuid: String? = UUID().uuidString
    var Username: String // E-Mail
    var ApiKey: String
    var Information: String
    
    enum CodingKeys: String, CodingKey {
        case uuid = "uuid"
        case Username = "Username"
        case ApiKey = "ApiKey"
        case Information = "Information"
    }
    
    static let empty = User(Username: "", ApiKey: "", Information: "")
    
    var current: User? {
        guard !self.list.isEmpty else { return nil }
        guard var user = self.list.first(where: { $0.ApiKey == UserStorage.shared.ApiKey }) else {
            return nil
        }
        
        if user.Information.isEmpty {
            user.Information = String(localized: "No Information")
        }
        
        return user
    }
    
    var list: [User] { UserStorage.shared.users }

    func save() {
        var userList = self.list
        userList.append(self)
        
        do {
            let data = try JSONEncoder().encode(userList)
            UserStorage.shared.UserAccounts = data
        } catch {
            print("Error encoding data: \(error)")
        }
    }
    
    func saveList(_ list: [User]) {
        do {
            let data = try JSONEncoder().encode(list)
            UserStorage.shared.UserAccounts = data
        } catch {
            print("Error encoding data: \(error)")
        }
    }
    
    func update() {
        var userList = self.list
        let index = userList.firstIndex(where: { $0.uuid == self.uuid})
        if (index != nil) {
            userList[index!] = self
            
            do {
                let data = try JSONEncoder().encode(userList)
                UserStorage.shared.UserAccounts = data
            } catch {
                print("Error encoding data: \(error)")
            }
        }
    }
    
    func delete() {
        var userList = self.list
        let removedKey = UserStorage.shared.ApiKey
        let removedOwners = userList.filter { $0.ApiKey == removedKey }.compactMap(\.uuid)
        userList.removeAll(where: { $0.ApiKey == removedKey })
        
        do {
            let data = try JSONEncoder().encode(userList)
            UserStorage.shared.UserAccounts = data
            guard UserStorage.shared.UserAccounts == data else { return }
            removedOwners.forEach(LocalNodeStore.removeOwner)
            UserStorage.shared.ApiKey = userList.first?.ApiKey ?? ""
            if UserStorage.shared.ApiKeyWidget == removedKey {
                UserStorage.shared.ApiKeyWidget = userList.first?.ApiKey ?? ""
                Task { _ = try? await ClearHealthCheckCacheIntent().perform() }
            }
        } catch {
            print("Error encoding data: \(error)")
        }
    }
}
