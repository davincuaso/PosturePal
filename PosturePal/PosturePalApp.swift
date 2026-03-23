//
//  PosturePalApp.swift
//  PosturePal
//
//  Real-time posture monitoring using Vision framework
//

import SwiftUI

@main
struct PosturePalApp: App {
    @StateObject private var healthKitManager = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
        }
    }
}
