import SwiftUI

struct tabView: View {
    @State private var selectedTab = 1 // Varsayılan olarak 'RequestView' sekmesini seç

    var body: some View {
        TabView(selection: $selectedTab) {
            ProfileView()
                .tabItem {
                   Image(systemName: "person.crop.circle")
                    Text("Profil")
                }
                .tag(0)
            
            RequestView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Talepler")
                }
                .tag(1)
            
            ChatView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Sohbet")
                }
                .tag(2)
        }
        .onAppear {
            // Başlangıçta seçili olan sekme
            selectedTab = 1
        }
    }
}

#Preview {
    tabView()
}
