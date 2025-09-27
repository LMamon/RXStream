//  Created by Louis Mamon on 6/5/25.

// TODO: Add app lifecycle hooks for graceful shutdown of UDP/TCP senders.
// TODO: Consider persisting last-used IP/port settings in UserDefaults.

import SwiftUI

@main
struct LiDARStreamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
