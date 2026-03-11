import SwiftUI

// ContentView is now just a pass-through to AppRouter
struct ContentView: View {
    var body: some View {
        AppRouter()
    }
}

#Preview {
    ContentView()
}