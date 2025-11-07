//
//  IPv64WidgetBundle.swift
//  IPv64Widget
//
//  Created by Sebastian Rank on 07.11.25.
//

import WidgetKit
import SwiftUI

@main
struct IPv64WidgetBundle: WidgetBundle {
    var body: some Widget {
        HealthcheckSmallWidget()
        HealthcheckMediumWidget()
        HealthcheckLargeWidget()
    }
}
