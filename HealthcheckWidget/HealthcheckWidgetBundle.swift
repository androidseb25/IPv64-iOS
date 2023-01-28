//
//  HealthcheckWidgetBundle.swift
//  HealthcheckWidget
//
//  Created by Sebastian Rank on 20.01.23.
//

import WidgetKit
import SwiftUI

@main
struct HealthcheckWidgetBundle: WidgetBundle {
    var body: some Widget {
        HealthcheckWidget()
        HealthcheckWidgetStatic()
    }
}
