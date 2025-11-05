//
//  SharedExtensions.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 04.11.25.
//

import Foundation

extension DateFormatter {
    static let db: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
