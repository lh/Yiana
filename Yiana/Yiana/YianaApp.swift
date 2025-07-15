//
//  YianaApp.swift
//  Yiana
//
//  Created by Luke Herbert on 15/07/2025.
//

import SwiftUI

@main
struct YianaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
