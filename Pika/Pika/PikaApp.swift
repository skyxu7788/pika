//
//  PikaApp.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import SwiftUI

@main
struct PikaApp: App {
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
