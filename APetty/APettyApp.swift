//
//  APettyApp.swift
//  APetty
//
//  Created by Seyma on 24.07.2024.
//

import SwiftUI
import FirebaseCore

@main
struct APettyApp: App {
    
    init(){
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
