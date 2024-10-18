//
//  TravelCompanionApp.swift
//  TravelCompanion
//
//  Created by Baylor Harrison on 3/16/24.
//

import SwiftUI

@main
struct TravelCompanionApp: App {
    // For CoreData
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
