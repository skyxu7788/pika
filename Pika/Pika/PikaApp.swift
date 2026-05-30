//
//  PikaApp.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import SwiftUI
import AVFoundation
import UIKit

@main
struct PikaApp: App {
    private let persistenceController = PersistenceController.shared

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
