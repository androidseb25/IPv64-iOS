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
            user.Information = "No Information"
        }
        
        return user
    }
    
    var list: [User] {
        let data = UserStorage.shared.UserAccounts
        var userList = [User]()
        do {
            if (!data.isEmpty) {
                userList = try JSONDecoder().decode([User].self, from: data)
                var isNilUUID = false
                userList = userList.map { u in
                    if (u.uuid == nil) {
                        var user = u
                        user.uuid = UUID().uuidString
                        isNilUUID = true
                        return user
                    }
                    return u
                }
                if (isNilUUID) {
                    User.empty.saveList(userList)
                }
            }
        } catch {
            print("Error decoding data: \(error)")
        }
        
        return userList
    }
    
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
        userList.removeAll(where: { $0.ApiKey == self.current!.ApiKey })
        
        do {
            let data = try JSONEncoder().encode(userList)
            UserStorage.shared.UserAccounts = data
            UserStorage.shared.ApiKey = userList.first?.ApiKey ?? ""
        } catch {
            print("Error encoding data: \(error)")
        }
    }
}
