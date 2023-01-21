//
//  SetupPrefs.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import Foundation

class SetupPrefs {
    
    static let preferences = UserDefaults(suiteName:"group.ipv64.net")
    static let preferencesStandard = UserDefaults.standard
    
    static func setPreference(mKey: String, mValue: Any) {
        preferences!.set(mValue, forKey: mKey)
        preferences!.synchronize()
    }
    
    static func readPreference(mKey: String, mDefaultValue: Any) -> Any {
        if preferences!.object(forKey: mKey) == nil {
            return mDefaultValue;
        } else {
            return preferences!.object(forKey: mKey) as Any
        }
    }
    
    static func readPreferenceStandard(mKey: String, mDefaultValue: Any) -> Any {
        if preferencesStandard.object(forKey: mKey) == nil {
            return mDefaultValue;
        } else {
            return preferencesStandard.object(forKey: mKey) as Any
        }
    }
    
    static func getArray(mKey: String, mType: String) -> Any {
        if mType.contains("string") {
            return preferences!.stringArray(forKey: mKey) ?? [String]()
        } else if mType.contains("int") {
            return preferences!.array(forKey: mKey) as? [Int] ?? [Int]()
        } else if mType.contains("date") {
            return preferences!.array(forKey: mKey) as? [Bool] ?? [Bool]()
        } else if mType.contains("bool") {
            return preferences!.array(forKey: mKey) as? [Date] ?? [Date]()
        } else {
            return []
        }
    }
    
    static func deletePreference(mKey: String) {
        preferences!.removeObject(forKey: mKey)
    }
}
